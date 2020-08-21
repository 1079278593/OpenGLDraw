//
//  DrawView.m
//  BrushDemo
//
//  Created by ming on 2018/5/7.
//  Copyright © 2018年 ming. All rights reserved.
//

#import "DrawView.h"
#import <GLKit/GLKit.h>
#import <OpenGLES/ES2/gl.h>
#import "fileUtil.h"
#import "shaderUtil.h"
#import "debug.h"
#import "UIImage+color.h"
#import "UIBezierPath+Geometry.h"
#import "LineGeometry.h"

// Shaders
enum {
    PROGRAM_POINT,
    NUM_PROGRAMS
};

enum {
    ATTRIB_VERTEX,
    ATTRIB_ROTATE,
    NUM_ATTRIBS
};

enum {
    UNIFORM_MVP,
    UNIFORM_POINT_SIZE,
    UNIFORM_VERTEX_COLOR,
    UNIFORM_TEXTURE,
    NUM_UNIFORMS
};//用这种方式，相对于location，第一个UNIFORM_MVP默认为0，递增。

typedef struct {
    char *vert, *frag;
    GLint uniform[NUM_UNIFORMS];
    GLuint id;
} programInfo_t;


// Texture
typedef struct {
    GLuint id;
    GLsizei width, height;
} textureInfo_t;


programInfo_t program[NUM_PROGRAMS] = {
    { "point.vsh",   "point.fsh" },     // PROGRAM_POINT
};

textureInfo_t textures[4] = {
};


#define kBrushOpacity        (1.0 / 3.0)
#define kBrushPixelStep        3
#define kBrushScale            2

@interface DrawView()
@property (nonatomic, strong) UIBezierPath *renderPath;
@property (nonatomic, strong) UIBezierPath *currentPath;
@property (nonatomic, assign) CGPoint ctlPoint;
@property (nonatomic, assign) CGFloat prePathLength;

@end

@implementation DrawView
{
    GLint backingWidth;
    GLint backingHeight;
    
    EAGLContext *context;
    textureInfo_t brushTexture;     // brush texture

    
    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    GLuint viewRenderbuffer, viewFramebuffer;
    GLuint depthRenderbuffer;
    GLuint vboId;
    
    GLfloat brushColor[4];          // brush color
    
    
    CGPoint location,previousLocation;
    CGPoint previousMidPoint;
    CGFloat brushWidth;
    NSString *brushTextImageName;
    UIColor *lineColor;

    GLuint textureLocation;
    
    BOOL firstTouch;
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (void)awakeFromNib{
    [super awakeFromNib];
    if ([self initContext]) {
        [self initGL];
        [self setupShaders];
        [self erase];
        [self setBrushColor:[UIColor redColor]];
        [self changeDrawWidth:30];
    }
}
- (void)layoutSubviews{
    [super layoutSubviews];
    self.backgroundColor = [UIColor whiteColor];
    [self setUpViewport];
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointZero];
    [path addLineToPoint:CGPointMake(30, 100)];
    [path addLineToPoint:CGPointMake(40, 130)];
    [path addLineToPoint:CGPointMake(50, 150)];
    [path addLineToPoint:CGPointMake(20, 100)];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        [self renderLinePath:path];
    });
}

#pragma mark - 初始化Context
- (BOOL)initContext{
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    // In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!context || ![EAGLContext setCurrentContext:context]) {
        return NO;
    }
    
    // Set the view's scale factor as you wish
    double scale = [[UIScreen mainScreen] scale];
    scale = 1;
    self.contentScaleFactor = scale;//这个scale会影响backingWidth和backingHeight
    return YES;
}

#pragma mark 初始化OpenGL
- (BOOL)initGL
{
    // Generate IDs for a framebuffer object and a color renderbuffer
    glGenFramebuffers(1, &viewFramebuffer);
    glGenRenderbuffers(1, &viewRenderbuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, viewFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
    // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
    //这个调用将当前渲染缓冲区的存储与EAGLDrawable(我们的CAEAGLLayer)关联起来。
    //允许我们绘制到缓冲区，稍后将渲染到屏幕上的任何层(这与我们的视图相对应)。
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)self.layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, viewRenderbuffer);//将渲染缓冲区挂载到当前帧缓冲区上
    
    /*
     *参考：https://www.jianshu.com/p/d7066d6a02cc
     
     一个完整的帧缓冲需要满足以下的条件：

     附加至少一个缓冲（颜色、深度或模板缓冲）。
     至少有一个颜色附件(Attachment)。
     所有的附件都必须是完整的（保留了内存）。
     每个缓冲都应该有相同的样本数。
     */
    
    //检查帧缓冲是否完整。
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    
    // Create a Vertex Buffer Object to hold our data
    glGenBuffers(1, &vboId);
    
    
    // Enable blending and set a blending function appropriate for premultiplied alpha pixel data
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    return YES;
}

#pragma mark 初始化Viewport
- (BOOL)setUpViewport
{
    // Allocate color buffer backing based on the current layer size
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"Failed to make complete framebuffer objectz %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    
    //viewing matrices: Update projection matrix
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
    GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
    
    // Update viewport
    glViewport(0, 0, backingWidth, backingHeight);
    
    return YES;
}

#pragma mark 清除内容
// Erases the screen
- (void)erase{
    [EAGLContext setCurrentContext:context];
    // Clear the buffer
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark- 开启着色器
- (void)setupShaders {
    for (int i = 0; i < NUM_PROGRAMS; i++)
    {
        char *vsrc = readFile(pathForResource(program[i].vert));
        char *fsrc = readFile(pathForResource(program[i].frag));
        GLsizei attribCount = 0;//
        GLchar *attribUsed[NUM_ATTRIBS];
        GLint attrib[NUM_ATTRIBS];
        GLchar *attribName[NUM_ATTRIBS] = {
            "inVertex","angle"
        };
        const GLchar *uniformName[NUM_UNIFORMS] = {
            "MVP", "pointSize", "vertexColor", "texture",
        };
        
        // auto-assign known attribs
        for (int j = 0; j < NUM_ATTRIBS; j++)
        {
            if (strstr(vsrc, attribName[j]))
            {
                attrib[attribCount] = j;//设置属性的location，根据j来。
                attribUsed[attribCount++] = attribName[j];//attribCt传递自身值，结束后自增。
            }
        }
        
        //创建program、编译、连接、绑定location
        glueCreateProgram(vsrc, fsrc,
                          attribCount, (const GLchar **)&attribUsed[0], attrib,
                          NUM_UNIFORMS, &uniformName[0], program[i].uniform,
                          &program[i].id);
        free(vsrc);
        free(fsrc);
        
        // Set constant/initalize uniforms
        if (i == PROGRAM_POINT)
        {
            glUseProgram(program[PROGRAM_POINT].id);
            
            // the brush texture will be bound to texture unit 0
            glUniform1i(program[PROGRAM_POINT].uniform[UNIFORM_TEXTURE], 0);
            
            /*
             *观测矩阵
             Ortho：正交；一个正交投影对于视点距离没有影响
             GLKMatrixMakeOrtho函数返回的矩阵通常与当前projectionMatrix级联来定义视域。
             */
            GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
            GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
            GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            
            glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
            
            // point size
            glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_POINT_SIZE], brushTexture.width / kBrushScale);
            
            // initialize brush color
            glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
            
            textureLocation = glGetUniformLocation(program[PROGRAM_POINT].id, "rotateLocation");

        }
    }
    
    glError();
}


#pragma mark 开启纹理
// Create a texture from an image
- (void)textureFromName:(NSString *)name color:(UIColor *)color
{
    brushTextImageName = name;
    
    CGImageRef        brushImage;
    CGContextRef    brushContext;
    GLubyte            *brushData;
    size_t            width, height;
    GLuint          texId;
    textureInfo_t   texture;
    
    // First create a UIImage object from the data in a image file, and then extract the Core Graphics image
    brushImage = [[UIImage imageNamed:name] imageWithColor:color].CGImage;//这个就是我要找的刷子啊！！！！！！但是又有点不同，这个刷子
    
    // Get the width and height of the image
    width = CGImageGetWidth(brushImage);
    height = CGImageGetHeight(brushImage);
    
    // Allocate  memory needed for the bitmap context
    brushData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
    // Use  the bitmatp creation function provided by the Core Graphics framework.
    brushContext = CGBitmapContextCreate(brushData, width, height, 8, width * 4, CGImageGetColorSpace(brushImage), kCGImageAlphaPremultipliedLast);
    // After you create the context, you can draw the  image to the context.
    CGContextDrawImage(brushContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), brushImage);
    // You don't need the context at this point, so you need to release it to avoid memory leaks.
    CGContextRelease(brushContext);
    // Use OpenGL ES to generate a name for the texture.
    glGenTextures(1, &texId);
    //        // Bind the texture name.
    glBindTexture(GL_TEXTURE_2D, texId);
    //        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    //        // Specify a 2D texture image, providing the a pointer to the image data in memory
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, brushData);
    //        // Release  the image data; it's no longer needed
    free(brushData);
    
    texture.id = texId;
//    texture.width = (int)width;
//    texture.height = (int)height;
    texture.width = (int)1;
    texture.height = (int)1;
    brushTexture = texture;
}

#pragma mark < render >
//这里绘制
- (BOOL)renderLinePath:(UIBezierPath *)berzierPath
{
    static GLfloat*        vertexBuffer = NULL;
    static NSUInteger    vertexMax = 64;
    NSUInteger            vertexCount = 0;
    static CGFloat    rotateAngel = 0;
    
    // Convert locations from Points to Pixels
    CGFloat scale = self.contentScaleFactor;

    // Allocate vertex array buffer
    if(vertexBuffer == NULL){
        vertexBuffer = malloc(vertexMax * 3 * sizeof(GLfloat));
    }
    CGFloat prePathLength = 0;
    CGFloat pathLength = berzierPath.length;
    CGFloat step = 1;
    CGRect bounds = self.bounds;

    if (pathLength > step) {
        while (prePathLength<pathLength) {
            prePathLength += step;
            CGPoint point = [berzierPath pointAtPercentOfLength:prePathLength/pathLength];
            point.y = bounds.size.height - point.y;
            point.x *= scale;
            point.y *= scale;//这个可以放到着色器去做。
            
            if(vertexCount == vertexMax) {
                vertexMax = 3 * vertexMax;
                vertexBuffer = realloc(vertexBuffer, vertexMax * 3 * sizeof(GLfloat));
            }
            CGFloat x = point.x;
            CGFloat y = point.y;
            rotateAngel = random() % 100;
            vertexBuffer[3 * vertexCount + 0] = x;
            vertexBuffer[3 * vertexCount + 1] = y;
            vertexBuffer[3 * vertexCount + 2] = rotateAngel;
            vertexCount += 1;
        }
    }else{
        return NO;
    }
    
    
    // Load data to the Vertex Buffer Object
    glBindBuffer(GL_ARRAY_BUFFER, vboId);
    glBufferData(GL_ARRAY_BUFFER, vertexCount*3*sizeof(GLfloat), vertexBuffer, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 3*sizeof(GLfloat), (GLfloat *)NULL);
    
    glEnableVertexAttribArray(ATTRIB_ROTATE);
    glVertexAttribPointer(ATTRIB_ROTATE, 1, GL_FLOAT, GL_FALSE, 3*sizeof(GLfloat), (GLfloat *)NULL + 2);
    
    // Draw
    glDrawArrays(GL_POINTS, 0, (int)vertexCount);
    
    // Display the buffer
    [context presentRenderbuffer:GL_RENDERBUFFER];
    
    return YES;
}

#pragma mark - touchesEvent
// Handles the continuation of a touch.
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [[event touchesForView:self] anyObject];
    previousLocation = [touch locationInView:self];
    
    self.currentPath = [UIBezierPath bezierPath];
    [self.currentPath moveToPoint:previousLocation];
    self.renderPath = [UIBezierPath bezierPathWithCGPath:self.currentPath.CGPath];
    firstTouch = YES;
}


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[event touchesForView:self] anyObject];
    
    location = [touch locationInView:self];
    
    if (self.renderPath == nil) {
        self.renderPath = [UIBezierPath bezierPath];
        [self.renderPath moveToPoint:self.currentPath.currentPoint];
    }
    
    if (CGPointEqualToPoint(self.ctlPoint, CGPointZero)) {
        self.ctlPoint = location;
        CGPoint midPoint = CGPointMake((self.currentPath.currentPoint.x + location.x) * 0.5, (self.currentPath.currentPoint.y + location.y) * 0.5);
        [self.currentPath addLineToPoint:midPoint];
        [self.renderPath addLineToPoint:midPoint];
    } else {
        CGPoint midPoint = CGPointMake((location.x + self.ctlPoint.x) * 0.5, (location.y + self.ctlPoint.y) * 0.5);
        [self.currentPath addQuadCurveToPoint:midPoint controlPoint:self.ctlPoint];
        self.ctlPoint = location;
        [self.renderPath addQuadCurveToPoint:midPoint controlPoint:self.ctlPoint];
        firstTouch = NO;
    }
    //上面的添加方式有问题，会导致线段间的点多次绘制，出现颜色叠加的情况。(或者在renderLinePath的两点分割出现问题)
    
    BOOL renderPath = [self renderLinePath:self.renderPath];
//    [self renderLineFromPoint:self.currentPath.currentPoint toPoint:location];
    if (renderPath) {
        self.renderPath = nil;
    }
}

// Handles the end of a touch event when the touch is a tap.
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    [self touchesMoved:touches withEvent:event];
    self.ctlPoint = CGPointZero;
}

#pragma mark - < 修改配置 >
- (void)changeBrushTexture:(NSString *)imgName{
    [self textureFromName:imgName color:lineColor];
}

- (void)changeDrawWidth:(CGFloat)width{
    CGFloat lineWidth = width * self.contentScaleFactor / [UIScreen mainScreen].scale;
    glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_POINT_SIZE], lineWidth);
    brushWidth = width;
}

- (void)setBrushColor:(UIColor *)newColor{
    CGFloat newRed, newGreen, newBlue, newAlpha;
    [newColor getRed:&newRed green:&newGreen blue:&newBlue alpha:&newAlpha];
    // Update the brush color
    brushColor[0] = newRed ;
    brushColor[1] = newGreen;
    brushColor[2] = newBlue;
    brushColor[3] = 1;
    glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
    [self textureFromName:brushTextImageName color:newColor];
    lineColor = newColor;
}

// Releases resources when they are not longer needed.
- (void)dealloc
{
    // Destroy framebuffers and renderbuffers
    if (viewFramebuffer) {
        glDeleteFramebuffers(1, &viewFramebuffer);
        viewFramebuffer = 0;
    }
    if (viewRenderbuffer) {
        glDeleteRenderbuffers(1, &viewRenderbuffer);
        viewRenderbuffer = 0;
    }
    if (depthRenderbuffer)
    {
        glDeleteRenderbuffers(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }
    // texture
    if (brushTexture.id) {
        glDeleteTextures(1, &brushTexture.id);
        brushTexture.id = 0;
    }
    // vbo
    if (vboId) {
        glDeleteBuffers(1, &vboId);
        vboId = 0;
    }
    
    // tear down context
    if ([EAGLContext currentContext] == context)
        [EAGLContext setCurrentContext:nil];
}

#pragma mark - < 没用到 >
// Drawings a line onscreen based on where the user touches
- (void)renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end
{
    static GLfloat*        vertexBuffer = NULL;
    static NSUInteger    vertexMax = 64;
    static CGFloat    rotateAngel = 0;

    NSUInteger            vertexCount = 0,
    count,
    i;
    
    
    // Convert locations from Points to Pixels
    CGFloat scale = self.contentScaleFactor;
    start.x *= scale;
    start.y *= scale;
    end.x *= scale;
    end.y *= scale;
    
    // Allocate vertex array buffer
    if(vertexBuffer == NULL)
        vertexBuffer = malloc(vertexMax * 3 * sizeof(GLfloat));
    
    // Add points to the buffer so there are drawing points every X pixels
    count = MAX(ceilf(hypot(end.x - start.x, end.y - start.y)) / (brushWidth/2), 1);
    for(i = 0; i < count; ++i) {
        if(vertexCount == vertexMax) {
            vertexMax = 3 * vertexMax;
            vertexBuffer = realloc(vertexBuffer, vertexMax * 3 * sizeof(GLfloat));
        }
        CGFloat x = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        CGFloat y = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        rotateAngel += M_PI_4;
        vertexBuffer[3 * vertexCount + 0] = x;
        vertexBuffer[3 * vertexCount + 1] = y;
        vertexBuffer[3 * vertexCount + 2] = rotateAngel;
        
        vertexCount += 1;
    }

    
    // Load data to the Vertex Buffer Object
    glBindBuffer(GL_ARRAY_BUFFER, vboId);
    glBufferData(GL_ARRAY_BUFFER, vertexCount*3*sizeof(GLfloat), vertexBuffer, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);//这里指向空，为什么还是要这么写？感觉是从vboId的buffer起始开始，不断读取。
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 3*sizeof(GLfloat), (CGFloat *)NULL);
    
//    glEnableVertexAttribArray(ATTRIB_ROTATE);
//    glVertexAttribPointer(ATTRIB_ROTATE, 1, GL_FLOAT, GL_FALSE, 3*sizeof(GLfloat), (CGFloat *)NULL+2);
    
    // Draw
    glDrawArrays(GL_POINTS, 0, (int)vertexCount);
    
    // Display the buffer
    [context presentRenderbuffer:GL_RENDERBUFFER];
}

@end

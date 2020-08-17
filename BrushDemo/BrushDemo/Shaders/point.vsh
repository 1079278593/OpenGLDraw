attribute vec4 inVertex;
attribute float angle;

uniform mat4 MVP;
uniform float pointSize;

uniform lowp vec4 vertexColor;
varying lowp vec4 color;

varying lowp mat4 rotation_matrix;
void main()
{
    
    float sin_theta = sin(angle);
    float cos_theta = cos(angle);
    mat4 rotation_matrix1 = mat4(cos_theta, sin_theta,0,0,
                                 -sin_theta, cos_theta,0,0,
                                 0,0,1,0,
                                 0,0,0,1);
    rotation_matrix = rotation_matrix1;
    
    
	gl_Position = MVP * inVertex;
    gl_PointSize = pointSize;
//    1 * 3.0;
//    color = vertexColor;
}

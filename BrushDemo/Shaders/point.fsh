uniform sampler2D texture;
//varying lowp vec4 color;


varying lowp mat4 rotation_matrix;
void main()
{
    gl_FragColor = texture2D(texture, (rotation_matrix * vec4(gl_PointCoord - vec2(0.5), 0.0, 1.0)).xy + vec2(0.5));
    gl_FragColor.a = gl_FragColor.a*0.6;
}

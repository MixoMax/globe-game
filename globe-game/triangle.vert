#version 330


layout (location = 0) in vec2 aPos;

out vec2 uv;

void main()
{
    uv = aPos + .5;
    gl_Position = vec4(aPos, 0.0, 1.0);
}
#pragma once
#include <glad/glad.h>
#include <GLFW/glfw3.h>

class Shader
{
private:
	GLuint vertexShader;
	GLuint fragmentShader;
	GLuint program;
public:
	
	Shader(const char* path);

	~Shader();

	void useShader() const;
	GLint getUniform(const char* name) const;
};


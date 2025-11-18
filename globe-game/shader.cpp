#include "shader.h"
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <string>

#include "fileWizard.h"

Shader::Shader(const char* path)
{
	const char* vertexShaderText = FileWizard::readFile((std::string(path)+ ".vert").c_str());
	const char* fragmentShaderText = FileWizard::readFile((std::string(path) + ".frag").c_str());

	vertexShader = glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(vertexShader, 1, &vertexShaderText, NULL);
	glCompileShader(vertexShader);

	fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(fragmentShader, 1, &fragmentShaderText, NULL);
	glCompileShader(fragmentShader);
	delete[] vertexShaderText;
	delete[] fragmentShaderText;

	program = glCreateProgram();
	glAttachShader(program, vertexShader);
	glAttachShader(program, fragmentShader);
	glLinkProgram(program);
	glValidateProgram(program);
}

Shader::~Shader()
{
	glDetachShader(program, vertexShader);
	glDetachShader(program, fragmentShader);
	glDeleteShader(vertexShader);
	glDeleteShader(fragmentShader);
	glDeleteProgram(program);
}

void Shader::useShader() const
{
	glUseProgram(program);
}

GLint Shader::getUniform(const char* name) const
{
	return glGetUniformLocation(program, name);
}

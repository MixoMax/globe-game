#pragma once
#include <functional>

#include <glad/glad.h>
#include <GLFW/glfw3.h>

class Mesh
{
private:
	GLuint vertexArray;
	GLuint vertexBuffer;
public:
	std::function<void()> render;
	Mesh(float* vertices, int size, std::function<void()> initFunction, std::function<void()> drawFunction);

	~Mesh();
};


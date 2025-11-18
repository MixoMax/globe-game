#define _CRT_SECURE_NO_WARNINGS
#define STB_IMAGE_IMPLEMENTATION
#include <glad/glad.h>
#include <GLFW/glfw3.h>

#include <iostream>
#include <stdlib.h>
#include <string>
#include <stddef.h>
#include <stdio.h>
#include <process.h>
#include <fstream>
#include <sstream>
#include <vector>
#include "shader.h"
#include "mesh.h"

//stb_image lagert kurzfristig viele Bytes auf dem Stack, sollte bei uns aber kein Problem sein.
#pragma warning(push)
#pragma warning(disable: 6262)
#include "stb_image.h"
#pragma warning(pop)

#include <crtdbg.h>//Recognizes Memory Leaks




/*Constants*/
static const float FPS = 60;





static int screenWidth = 500;
static int screenHeight = 400;
static float screenRatio = static_cast<float>(screenWidth / screenHeight);

/**
 *
 */
int main(void)
{
	std::cout << "Program started" << std::endl;

	GLFWwindow* window;

	/* Initialize the library */
	if (!glfwInit())
	{
		std::cerr << "Failed: GLFW init" << std::endl;
		return -1;
	}

	/*Error Handling*/
	glfwSetErrorCallback([](int error, const char* description) {
		std::cerr << "Unknown ERROR in GLFW (Code " << error << ") with description" << std::endl;
		std::cerr << description << std::endl;
		});


	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);



	GLFWvidmode videoMode = *glfwGetVideoMode(glfwGetPrimaryMonitor());
	screenWidth = videoMode.width;
	screenHeight = videoMode.height;
	screenRatio = static_cast<float>(screenWidth) / static_cast<float>(screenHeight);

	std::cout << "Aufloesung von " << screenWidth << "*" << screenHeight << " Pixeln." << std::endl;

	/* Create a windowed mode window and its OpenGL context */
	window = glfwCreateWindow(screenWidth, screenHeight, "VoxelEngine", glfwGetPrimaryMonitor(), NULL);
	//window = glfwCreateWindow(screenWidth, screenHeight, "VoxelEngine", NULL, NULL);
	if (!window)
	{
		std::cerr << "Failed: Create Window" << std::endl;
		glfwTerminate();
		return -1;
	}
	glfwMaximizeWindow(window);

	/* Make the window's context current */
	glfwMakeContextCurrent(window);

	if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
		std::cerr << "Failed: Initializing GLAD" << std::endl;
		return -1;
	}

	//VSync
	glfwSwapInterval(1);

	glfwSetFramebufferSizeCallback(window, [](GLFWwindow* window, int width, int height) {
		screenWidth = width;
		screenHeight = height;
		screenRatio = width / (float)height;
		glViewport(0, 0, screenWidth, screenHeight);
		});

	glClearColor(1.0, 0, 0, 1);


	/*
	 * Instantiate Objects
	 */
	Shader triangleShader{"triangle"};
	float vertices[6]{
		-.5f,-.5f,
		 .5f,-.5f,
		 .5f, .5f
	};

	Mesh triangleMesh{vertices, sizeof(vertices), 
		[]() {
			glEnableVertexAttribArray(0);
			glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 2, 0);
			glDisableVertexAttribArray(0);
		},
		[]() { /*Renderfunction*/
			glEnableVertexAttribArray(0);

			glDrawArrays(GL_TRIANGLES, 0, 3);

			glDisableVertexAttribArray(0);
		} };
	
	glfwShowWindow(window);
	double lastFrame = glfwGetTime();
	double dT = 1;
	double timePerFrame = 1 / FPS;
	double nextFrame = lastFrame + timePerFrame;
	std::cout << "> Entering Renderloop..." << std::endl;
	/* Loop until the user closes the window */
	while (!glfwWindowShouldClose(window))
	{
		double now = glfwGetTime();
		if (now >= nextFrame) {
			nextFrame = now + timePerFrame;
			glClear(GL_COLOR_BUFFER_BIT);
			

			triangleShader.useShader();
			triangleMesh.render();


			/* Swap front and back buffers */
			glfwSwapBuffers(window);

			now = glfwGetTime();
			dT = (now - lastFrame + 0.0000001f);
			glfwSetWindowTitle(window, std::to_string(1 / dT).c_str());
			//std::cout << 1/(now - time) << std::endl;
			lastFrame = now;
		}

		/* Poll for and process events */
		glfwPollEvents();
	}


	/*
	 * Deconstruct
	 */

	

	glfwDestroyWindow(window);
	glfwTerminate();
	std::cout << "> Program stopped succesfully!" << std::endl;

	_CrtDumpMemoryLeaks();
	system("pause");
	return 0;
}
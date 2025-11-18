#define _CRT_SECURE_NO_WARNINGS
#include "fileWizard.h"
#include <sstream>
#include <fstream>
#include <iostream>

char* FileWizard::readFile(const char* fileName)
{
	std::ifstream file;

	try
	{
		file.open(fileName);
		std::stringstream buffer;
		buffer << file.rdbuf();
		file.close();
		std::string content = buffer.str();

		const size_t length = content.size() + 1;
		char* result = new char[length];
		std::strcpy(result, content.c_str());
		return result;
	}
	catch (std::ifstream::failure e) {
		std::cerr << "Failed: Read File " << fileName << std::endl;
		file.close();
		char* empty = new char[1];
		empty[0] = '\0';
		return empty;
	}
}


#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "DS_timer.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <windows.h>
#include <conio.h>

#define ROW 32
#define COL 32

#define NONE -1
#define DEAD 0
#define LIVE 1
#define PLAYER 2

#define UP 119 // WŰ
#define LEFT 97 // AŰ
#define DOWN 115 // SŰ
#define RIGHT 100 // DŰ


void initfield(int* _gamefield1, int* _gamefield2, int* Player_Location);
void draw(int* _gamefield);
void Menu();

__global__ void game(int* gamefieldOriginal, int* gamefieldBuffer)
{
	int width = blockDim.x;
	int height = gridDim.x;
	int blockID = threadIdx.x;

	int gridID = blockDim.x * blockIdx.x + blockID;

	if (gamefieldOriginal[gridID] == NONE) {
		gamefieldBuffer[gridID] = NONE;
	}
	else {
		int neighbors = 0;
		if (gamefieldOriginal[gridID - width - 1] == LIVE || gamefieldOriginal[gridID - width - 1] == PLAYER) { // upper left.
			neighbors++;
		}
		if (gamefieldOriginal[gridID - width] == LIVE || gamefieldOriginal[gridID - width] == PLAYER) { // upper.
			neighbors++;
		}
		if (gamefieldOriginal[gridID - width + 1] == LIVE || gamefieldOriginal[gridID - width + 1] == PLAYER) { // upper right.
			neighbors++;
		}
		if (gamefieldOriginal[gridID - 1] == LIVE || gamefieldOriginal[gridID - 1] == PLAYER) { // left.
			neighbors++;
		}
		if (gamefieldOriginal[gridID + 1] == LIVE || gamefieldOriginal[gridID + 1] == PLAYER) { // right.
			neighbors++;
		}
		if (gamefieldOriginal[gridID + width - 1] == LIVE || gamefieldOriginal[gridID + width - 1] == PLAYER) { // lower left.
			neighbors++;
		}
		if (gamefieldOriginal[gridID + width] == LIVE || gamefieldOriginal[gridID + width] == PLAYER) { // lower.
			neighbors++;
		}
		if (gamefieldOriginal[gridID + width + 1] == LIVE || gamefieldOriginal[gridID + width + 1] == PLAYER) { // lower right.
			neighbors++;
		}

		if (gamefieldOriginal[gridID] == DEAD) {
			if (neighbors == 3) {
				gamefieldBuffer[gridID] = LIVE;
			}
		}
		else if (gamefieldOriginal[gridID] == LIVE) {
			if (neighbors < 2 || neighbors > 3) {
				gamefieldBuffer[gridID] = DEAD;
			}
		}
	}

}

__global__ void copy(int* gamefieldOriginal, int* gamefieldBuffer) {
	int width = blockDim.x;
	int height = gridDim.x;
	int blockID = threadIdx.x;

	int gridID = blockDim.x * blockIdx.x + blockID;
	gamefieldOriginal[gridID] = gamefieldBuffer[gridID];
}

int main()
{
	srand(time(NULL));

	int width = COL;
	int height = ROW;
	int size = sizeof(int) * width * height;

	int term = 30;
	int count = 0;

	int* Player_Location = new int;
	*Player_Location = COL + 1; // �÷��̾��� ���� ���� �������ִ� ��
	int eat = 0; // ��Ƹ��� ���� ��
	

	int* gamefieldParallelHost;
	int* gamefieldParallelCUDA;
	int* gamefieldBufferCUDA;
	int* gamefieldPlayer; // �÷��̾��� ��ġ�� ����ٰ� �ٲ㼭 �ٲ� ����� ����̽� �޸𸮿� �����Ұ���

	cudaMalloc(&gamefieldParallelCUDA, size);
	cudaMalloc(&gamefieldBufferCUDA, size);

	gamefieldParallelHost = new int[width * height];
	gamefieldPlayer = new int[width * height];

	memset(gamefieldParallelHost, 0, size);
	memset(gamefieldPlayer, 0, size);

	initfield(gamefieldParallelHost, gamefieldPlayer, Player_Location);

	dim3 dimBlock(width);
	dim3 dimGrid(height);

	cudaMemcpy(gamefieldBufferCUDA, gamefieldParallelHost, size, cudaMemcpyHostToDevice);
	cudaMemcpy(gamefieldParallelCUDA, gamefieldParallelHost, size, cudaMemcpyHostToDevice);

	char key = '\0'; // Ű���� �Է� ���� �� �ʱ�ȭ

	Menu();

	while (count < term)
	{
		// ������ �����ϱ����� ���� Ű���� �Է��� �޾ƾ� count�� ���� �����ϸ� ������ ���۵ȴ�
		// W : ���� �̵� A: �������� �̵� S: �Ʒ��� �̵� D : ���������� �̵�
		// �� �����δ� ������ ���Ѵ�
		// term �ð� ���� ��Ƹ��� ���� ���� �� ����

		cudaMemcpy(gamefieldPlayer, gamefieldParallelCUDA, size, cudaMemcpyDeviceToHost);

		if (_kbhit()) // Ű �Է¹����� true �����ϴ� �Լ�
		{
			// �÷��̾��� ��ġ�� Player_temp ������ ����
			int Player_temp = *Player_Location;

			key = _getch(); // �Է¹��� Ű ���� key ������ ����

			if (key == UP) // WŰ �Է½� ���� �̵�
			{
				Player_temp = Player_temp - COL;
			}
			else if (key == LEFT) // AŰ �Է½� ���� �̵�
			{
				Player_temp = Player_temp - 1;
			}
			else if (key == DOWN) // SŰ �Է½� �Ʒ��� �̵�
			{
				Player_temp = Player_temp + COL;
			}
			else if (key == RIGHT) // DŰ �Է½� ������ �̵�
			{
				Player_temp = Player_temp + 1;
			}
			else
			{
				printf("�߸� �Է��߽��ϴ�!!!!!\n");
			}

			// �̵��ϰ��� �ϴ� ���� �� �� ������ �̵��� �Ұ�
			if (gamefieldPlayer[Player_temp] == NONE)
				printf("���̶� ������!!!!!!\n");
			else
			{
				if (gamefieldPlayer[Player_temp] == LIVE) // �̵��� ���� ������ ��������� ����
					eat++;

				gamefieldPlayer[*Player_Location] = DEAD; // �̵��ϱ����� ���� �ִ� ���� DEAD ���·� �ٲ���
				*Player_Location = Player_temp; 
				gamefieldPlayer[*Player_Location] = PLAYER; // �̵��� ���� ���ο� �÷��̾��� ��ġ�� ����

				// �ٲ� gamefieldPlayer�� Ŀ�� �޸𸮿� ��������
				cudaMemcpy(gamefieldParallelCUDA, gamefieldPlayer, size, cudaMemcpyHostToDevice); 
				cudaMemcpy(gamefieldBufferCUDA, gamefieldPlayer, size, cudaMemcpyHostToDevice);
			}
		}

		// 1�ʸ��� Ŀ�� �Լ����� �����(1�ʸ��� ���� �׷���)
		game << <dimGrid, dimBlock >> > (gamefieldParallelCUDA, gamefieldBufferCUDA);
		copy << <dimGrid, dimBlock >> > (gamefieldParallelCUDA, gamefieldBufferCUDA);

		cudaDeviceSynchronize();
		cudaMemcpy(gamefieldParallelHost, gamefieldParallelCUDA, size, cudaMemcpyDeviceToHost);

		draw(gamefieldParallelHost);
		printf("���� ���� ���� �� : %d\n", eat);
		printf("%d�� ���ҽ��ϴ�\n", term - count);
		Sleep(1000);
		count++;
		system("cls");
	}
	
	printf("�� ���� ���� : %d\n", eat);

	cudaFree(gamefieldParallelCUDA);
	cudaFree(gamefieldBufferCUDA);

	delete[] gamefieldPlayer; delete[] gamefieldParallelHost;
	return 0;
}

void initfield(int* _gamefield1, int* _gamefield2 ,int* _Player_Location)
{
	for (int i = 0; i < ROW * COL; i++)
		_gamefield1[i] = rand() % 2;

	for (int i = 0; i < COL; i++)
	{
		_gamefield1[i] = NONE; // �� ��
		_gamefield1[i + COL * (ROW - 1)] = NONE; // �� �Ʒ�
	}

	for (int i = 0; i < ROW; i++)
	{
		_gamefield1[COL * i] = NONE; // �� ����
		_gamefield1[COL * (i + 1) - 1] = NONE; // �� ������
	}

	_gamefield1[*_Player_Location] = PLAYER;

	for (int i = 0; i < ROW * COL; i++) {
		_gamefield2[i] = _gamefield1[i];
	}
}

void draw(int* _gamefield)
{
	for (int i = 0; i < ROW; i++)
	{
		for (int j = 0; j < COL; j++)
		{
			printf("[%2d]", _gamefield[i * ROW + j]);
		}
		printf("\n");
	}
}

void Menu()
{
	printf("-----------------------------------------------------------------------\n");
	printf("\t\t\t���� �Ա� �����Դϴ�\n");
	printf("�÷��̾��� ��ŸƮ�� �� ���� �� ��ġ���� �����մϴ�(WASD�� �̵��غ�����)\n");
	printf("\t\t(����) �����δ� ���� ���մϴ�\n");
	printf("���� �ð����� ������ �󸶳� ���� ���� �� �ִ��� �����غ�����\n");
	printf("\t\t�������� ����ؼ� �װų� �����˴ϴ�\n");
	printf("-----------------------------------------------------------------------\n");

	for (int i = 0; i < 10; i++)
	{
		printf("%d�� �Ŀ� ���۵˴ϴ�\n", 10 - i);
		Sleep(1000);
	}
	system("cls");
}
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

#define UP 119 // W키
#define LEFT 97 // A키
#define DOWN 115 // S키
#define RIGHT 100 // D키


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
	*Player_Location = COL + 1; // 플레이어의 시작 지점 설정해주는 곳
	int eat = 0; // 잡아먹은 세포 수
	

	int* gamefieldParallelHost;
	int* gamefieldParallelCUDA;
	int* gamefieldBufferCUDA;
	int* gamefieldPlayer; // 플레이어의 위치를 여기다가 바꿔서 바꾼 결과를 디바이스 메모리에 복사할것임

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

	char key = '\0'; // 키보드 입력 받을 값 초기화

	Menu();

	while (count < term)
	{
		// 게임을 시작하기전에 먼저 키보드 입력을 받아야 count를 세기 시작하며 게임이 시작된다
		// W : 위로 이동 A: 왼쪽으로 이동 S: 아래로 이동 D : 오른쪽으로 이동
		// 벽 밖으로는 나가지 못한다
		// term 시간 동안 잡아먹은 세포 수를 셀 것임

		cudaMemcpy(gamefieldPlayer, gamefieldParallelCUDA, size, cudaMemcpyDeviceToHost);

		if (_kbhit()) // 키 입력받으면 true 리턴하는 함수
		{
			// 플레이어의 위치를 Player_temp 변수에 복사
			int Player_temp = *Player_Location;

			key = _getch(); // 입력받은 키 값을 key 변수에 저장

			if (key == UP) // W키 입력시 위로 이동
			{
				Player_temp = Player_temp - COL;
			}
			else if (key == LEFT) // A키 입력시 왼쪽 이동
			{
				Player_temp = Player_temp - 1;
			}
			else if (key == DOWN) // S키 입력시 아래쪽 이동
			{
				Player_temp = Player_temp + COL;
			}
			else if (key == RIGHT) // D키 입력시 오른쪽 이동
			{
				Player_temp = Player_temp + 1;
			}
			else
			{
				printf("잘못 입력했습니다!!!!!\n");
			}

			// 이동하고자 하는 곳이 갈 수 없으면 이동이 불가
			if (gamefieldPlayer[Player_temp] == NONE)
				printf("벽이라 못가요!!!!!!\n");
			else
			{
				if (gamefieldPlayer[Player_temp] == LIVE) // 이동할 곳에 세포가 살아있으면 먹음
					eat++;

				gamefieldPlayer[*Player_Location] = DEAD; // 이동하기전에 원래 있던 곳을 DEAD 상태로 바꿔줌
				*Player_Location = Player_temp; 
				gamefieldPlayer[*Player_Location] = PLAYER; // 이동한 곳을 새로운 플레이어의 위치로 설정

				// 바꾼 gamefieldPlayer를 커널 메모리에 복사해줌
				cudaMemcpy(gamefieldParallelCUDA, gamefieldPlayer, size, cudaMemcpyHostToDevice); 
				cudaMemcpy(gamefieldBufferCUDA, gamefieldPlayer, size, cudaMemcpyHostToDevice);
			}
		}

		// 1초마다 커널 함수들이 실행됨(1초마다 맵이 그려짐)
		game << <dimGrid, dimBlock >> > (gamefieldParallelCUDA, gamefieldBufferCUDA);
		copy << <dimGrid, dimBlock >> > (gamefieldParallelCUDA, gamefieldBufferCUDA);

		cudaDeviceSynchronize();
		cudaMemcpy(gamefieldParallelHost, gamefieldParallelCUDA, size, cudaMemcpyDeviceToHost);

		draw(gamefieldParallelHost);
		printf("현재 먹은 세포 수 : %d\n", eat);
		printf("%d초 남았습니다\n", term - count);
		Sleep(1000);
		count++;
		system("cls");
	}
	
	printf("총 먹은 개수 : %d\n", eat);

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
		_gamefield1[i] = NONE; // 맨 위
		_gamefield1[i + COL * (ROW - 1)] = NONE; // 맨 아래
	}

	for (int i = 0; i < ROW; i++)
	{
		_gamefield1[COL * i] = NONE; // 맨 왼쪽
		_gamefield1[COL * (i + 1) - 1] = NONE; // 맨 오른쪽
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
	printf("\t\t\t세포 먹기 게임입니다\n");
	printf("플레이어의 스타트는 맨 왼쪽 위 위치부터 시작합니다(WASD로 이동해보세요)\n");
	printf("\t\t(주의) 벽으로는 가지 못합니다\n");
	printf("제한 시간내에 세포를 얼마나 많이 먹을 수 있는지 도전해보세요\n");
	printf("\t\t세포들은 계속해서 죽거나 생성됩니다\n");
	printf("-----------------------------------------------------------------------\n");

	for (int i = 0; i < 10; i++)
	{
		printf("%d초 후에 시작됩니다\n", 10 - i);
		Sleep(1000);
	}
	system("cls");
}
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/stat.h>
#include <ctype.h>
#include <dirent.h>

int main(int argc, char **argv) {
	if (argc != 2) {
		fprintf(stderr, "wrong\n");
		return 1;
	}

	char *pname = argv[1];
	char *pid = NULL;

	char sprints[256];

	DIR *dir = opendir("/proc");
	char comm[256];

	struct dirent *de;
	while ((de = readdir(dir)) != NULL) {
		if (!isdigit(*de->d_name)) continue;
		sprintf(sprints, "/proc/%s/comm", de->d_name);
		FILE *fp = fopen(sprints, "r");
		comm[fread(comm, 1, sizeof(comm), fp)-1] = 0;
		if (strcmp(comm, pname) == 0) {
			pid = de->d_name; 
			break;
		}
	}

	if (pid == NULL) {
		fprintf(stderr, "doesnt\n");
		return 1;
	}

	char cwd[256];
	char exe[256];

	sprintf(sprints, "/proc/%s", pid);
	struct stat statbuf;

	if (stat(sprints, &statbuf) != 0) {
		fprintf(stderr, "cant\n");
		return 1;
	}

	int uid = statbuf.st_uid;

	int cuid = getuid();
	if (cuid != 0 && cuid != uid) {
		fprintf(stderr, "no\n");
		return 1;
	}

	sprintf(sprints, "/proc/%s/cwd", pid);
	cwd[readlink(sprints, cwd, sizeof(cwd))] = 0;

	sprintf(sprints, "/proc/%s/exe", pid);
	exe[readlink(sprints, exe, sizeof(exe))] = 0;

	sprintf(sprints, "/proc/%s/environ", pid);
	FILE *efd = fopen(sprints, "r");
	char *environ = malloc(123456);
	char **env = malloc(4097);
	fread(environ, 1, 123456, efd);
	fclose(efd);
	for (int i = 0; *environ; i++) {
		env[i] = environ;
		env[i+1] = 0;
		environ += strlen(environ) + 1;
	}

	sprintf(sprints, "/proc/%s/cmdline", pid);
	FILE *cfd = fopen(sprints, "r");
	char *cmdline = malloc(123456);
	char **cmd = malloc(4097);
	fread(cmdline, 1, 123456, cfd);
	fclose(cfd);
	for (int i = 0; *cmdline; i++) {
		cmd[i] = cmdline;
		cmd[i+1] = 0;
		cmdline += strlen(cmdline) + 1;
	}

	kill(atoi(pid), 9);
	if (fork() != 0) {
		return 0;
	}

	setuid(uid);
	chdir(cwd);
	close(1);
	execve(exe, cmd, env);
}


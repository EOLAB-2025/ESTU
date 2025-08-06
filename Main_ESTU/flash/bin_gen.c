#include <stdio.h>

#include "flash_input.txt"

int main(void)
{
    FILE *file;

    file = fopen("to_flash/flash_bin.bin", "wb");
    fwrite(flash, sizeof(flash), 1, file);
    fclose(file);


    return 0;
}

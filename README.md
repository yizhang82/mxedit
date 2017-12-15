# 16-bit DOS Editor in 16-bit assembly from the good old days - MXEdit

I was looking at some of the pretty old program I wrote in my early days for nostalgia, and decided to put some of them on github just for fun. 

This is a 16-bit DOS editor written entirely in assembly code back in 2002. I don't remember why I decided to write a DOS editor at that time - I'm assuming I was pretty nostalgic for the DOS days in the 90s.... This is the biggest assembly code project (2205 lines) I've wrote ever (and probably will always be). The most assembly code I wrote these days are proably in the few 100s - they are just *stubs* to get some job done that can't be done in C (self-relocating stubs, for example). 

This editor doesn't do much - but does have all the basics you'll need in an editor back in the day. Sorry, no syntax highlighting. No embeded OLE/COM for your fancy VISIO chart either. 

It has a *trendy* (at DOS days) blue background with gray font (Microsoft C/C++ Programmer Work Bench, anyone?). 

![MXEdit 1](/img/MXEdit_1.jpg)

It even has a little cute TurboC / QuickBasic style menu draw in ASCII:

![MXEdit 2](/img/MXEdit_2.jpg)

## Some technical details

As a 16-bit DOS program, it calls to DOS 21h for OS functionality. You set AH to the function ID you want, and INT 21h:
* AH = 48/49/4A for memory alloc/free/realloc (See Memory.asm)
* AH = 3D/3E/3F/40 for file open/close/read/write (See File.asm)

To display text, you can use INT10H, AH=0 to set video mode then write to mapped video memory directly. The golden standard is of course 80x25 with all generous 16 colors. The video memory is mapped at B800H and is laid in 25 rows, and each row has 80 of WORD, first byte being the character and 2nd byte being color attribute (you can do fancy things like blinking text, etc). All the video memory related functionality is in text.asm.

The editor itself uses a pretty simple double link list structure to maintain the lines, which has a pointer to the actual text which can expand ondemand through realloc (21h/AH=4A).  All the editor functionality - the main loop, reading character input (INT21h/AH=08H), making text manipulations, drawing menus, etc, are all in MXEdit.asm.

For more information:
1. [DOS INT 21h interrupt](https://en.wikipedia.org/wiki/MS-DOS_API)
2. [BIOS INT 10h interrupt](https://en.wikipedia.org/wiki/INT_10H)

## How to build

You need the Microsoft Macro Assembler, which are included in Visual Studio. 

You'll also need a 16-bit linker - which you can find in [this link](http://www.kipirvine.com/asm/examples/Irvine_7th_Edition.msi) (from Irvine's assembly language book site http://www.kipirvine.com/).

To build, open a Visual Studio developer prompt (I tested using VS 2017), and run build.bat. It assumes your 16-bit linker is located at C:\irvine. The linker will ask you a bunch of questions - just take default for everything.

If the build completes successfully, you'll see a 16-bit MXEDIT.exe.

## How to run

To run the program, you'll need a OS that runs 16-bit programs. Latest 64-bit Windows no longer supports 16-bit programs. You can enable legacy NTVDM component in 32-bit OS though if you have one. Or use a emulator to boot up a DOS image.

However, the easiest way is to download [DOSBOX](http://www.dosbox.com). Inside DosBox, mount a drive to the folder where MXEDIT.exe lives, and run it. 


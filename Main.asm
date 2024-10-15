; ===============================================================================
;   Copyright 2023 Ilya Lyakhovets
;
;   This program is free software: you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, either version 3 of the License, or
;   (at your option) any later version.
; 
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program.  If not, see <http://www.gnu.org/licenses/>.
; ===============================================================================

; Asteroids game written on x64 MASM assembly

option casemap:none

; Init & Kill
MessageBoxA proto
ExitProcess proto
GetModuleHandleA proto
LoadIconA proto
LoadCursorA proto
RegisterClassA proto
ChangeDisplaySettingsA proto
AdjustWindowRectEx proto
GetSystemMetrics proto
CreateWindowExA proto
GetDC proto
ChoosePixelFormat proto
SetPixelFormat proto
wglCreateContext proto
wglMakeCurrent proto
wglDeleteContext proto
ReleaseDC proto
DestroyWindow proto
UnregisterClassA proto

; Common
SetCursor proto
SetFocus proto
SetForegroundWindow proto
ShowWindow proto
UpdateWindow proto
PeekMessageA proto
TranslateMessage proto
DispatchMessageA proto
PostQuitMessage proto
ValidateRect proto
DefWindowProcA proto
SwapBuffers proto
memset proto
strcat proto
strrchr proto
sinf proto
cosf proto
srand proto
rand proto
time proto
PlaySound proto
fopen proto
fscanf proto
GetModuleFileNameA proto
timeGetTime proto

; OpenGL
glShadeModel proto
glDepthFunc proto
glHint proto
glEnable proto
glDisable proto
glTranslatef proto
glRotatef proto
glLoadIdentity proto
glMatrixMode proto
glPushMatrix proto
glPopMatrix proto
glOrtho proto
glScissor proto
glViewport proto
glClearColor proto
glClearDepth proto
glClear proto
glBegin proto
glEnd proto
glVertex2f proto
glVertex2d proto
glColor3f proto
glPointSize proto
glLineWidth proto

includelib legacy_stdio_definitions.lib
includelib libcmtd.lib
includelib vcruntime.lib
includelib ucrt.lib
includelib gdi32.lib
includelib winmm.lib
includelib user32.lib
includelib kernel32.lib
includelib OpenGL32.lib

.data?

hRC qword ?
hDC qword ?                                    
hWnd qword ?
hInstance qword ?

NUMDISPLAY struct 8
        top byte ?
        topLeft byte ?
        topRight byte ?
        center byte ?
        bottomLeft byte ?
        bottomRight byte ?
        bottom byte ?
NUMDISPLAY ends

POINT struct 8
        x dword ?
        y dword ?
POINT ends

POINTF struct 8
        x dd ?
        y dd ?
POINTF ends

; Rectangle
RECT struct 8
        left dword ?
        top dword ?
        right dword ?
        bottom dword ?
RECT ends

DEVMODEA struct 8
        dmDeviceName byte 32 DUP(?)
        dmSpecVersion word ?
        dmDriverVersion word ?
        dmSize word ?
        dmDriverExtra word ?
        dmFields dword ?

        union DUMMYUNIONNAME
                struct DUMMYSTRUCTNAME 
                        dmOrientation word ?
                        dmPaperSize word ?
                        dmPaperLength word ?
                        dmPaperWidth word ?
                        dmScale word ?
                        dmCopies word ?
                        dmDefaultSource word ?
                        dmPrintQuality word ?
                ends

                struct DUMMYSTRUCTNAME2
                        dmPosition POINT<>
                        dmDisplayOrientation DWORD ?
                        dmDisplayFixedOutput DWORD ?
                ends
        ends

        dmColor word ?
        dmDuplex word ?
        dmYResolution word ?
        dmTTOption word ?
        dmCollate word ?
        dmFormName byte 32 DUP(?)
        dmLogPixels word ?
        dmBitsPerPel DWORD ?
        dmPelsWidth DWORD ?
        dmPelsHeight DWORD ?

        union DUMMYUNIONNAME2
                dmDisplayFlags dword ?
                dmNup dword ?
        ends

        dmDisplayFrequency dword ?
        dmICMMethod dword ?
        dmICMIntent dword ?
        dmMediaType dword ?
        dmDitherType dword ?
        dmReserved1 dword ?
        dmReserved2 dword ?
        dmPanningWidth dword ?
        dmPanningHeight dword ?
DEVMODEA ends

; Windows class
WNDCLASSA struct 8
        style dword ?
        lpfnWndProc qword ?
        cbClsExtra dword ?
        cbWndExtra dword ?
        hInstance qword ?
        hIcon qword ?
        hCursor qword ?
        hbrBackground qword ?
        lpszMenuName qword ?
        lpszClassName qword ?
WNDCLASSA ends

; Pixel format descriptor
PIXELFORMATDESCRIPTOR struct 8
        nSize word ?
        nVersion word ?
        dwFlags dword ?
        iPixelType byte ?
        cColorBits byte ?
        cRedBits byte ?
        cRedShift byte ?
        cGreenBits byte ?
        cGreenShift byte ?
        cBlueBits byte ?
        cBlueShift byte ?
        cAlphaBits byte ?
        cAlphaShift byte ?
        cAccumBits byte ?
        cAccumRedBits byte ?
        cAccumGreenBits byte ?
        cAccumBlueBits byte ?
        cAccumAlphaBits byte ?
        cDepthBits byte ?
        cStencilBits byte ?
        cAuxBuffers byte ?
        iLayerType byte ?
        bReserved byte ?
        dwLayerMask dword ?
        dwVisibleMask dword ?
        dwDamageMask dword ?
PIXELFORMATDESCRIPTOR ends

pixelFormat dword ?

MESSAGE struct 8
        hwnd qword ?
        message dword ?
        wParam qword ?
        lParam qword ?
        time dword ?
        pt POINT <>
MESSAGE ends

SHIP struct 8
        accelerating byte ?
        destroyed byte ?
        rot dd ?
        vel POINTF <0.0, 0.0>
        pos POINTF <0.0, 0.0>
SHIP ends

ASTEROID struct 8
        active byte ?
        sizeType word ?
        rot dd ?
        rotSpeed dd ?
        vel POINTF <0.0, 0.0>
        pos POINTF <0.0, 0.0>
ASTEROID ends

BULLET struct 8
        active byte ?
        vel POINTF <0.0, 0.0>
        pos POINTF <0.0, 0.0>
BULLET ends

MAX_PARTICLES equ 80

EFFECT struct 8
        time dd ?
        vel POINTF MAX_PARTICLES dup (<0.0, 0.0>)
        pos POINTF MAX_PARTICLES dup (<0.0, 0.0>)
EFFECT ends

; Wrapper for EFFECT structure.
; It seems like MASM doesn't allow to allocate an array of EFFECT using DUP directive.
; So, this workaround solves the issue.
WRAPPER_EFFECT struct 8
        data EFFECT <0>
WRAPPER_EFFECT ends

.data

; Main
WINDOW_WIDTH dword 1920
WINDOW_HEIGHT dword 1080
FULLSCREEN byte 1

; Register class
CS_HREDRAW equ 2h
CS_VREDRAW equ 1h
CS_OWNDC equ 20h
IDC_ARROW equ 7F00h
IDI_APPLICATION equ 7F00h
className db "Asteroids", 0
wc WNDCLASSA <0, 0, 0, 0, 0, 0, 0, 0, 0>

; Fullscreen
DM_PELSWIDTH equ 80000h
DM_PELSHEIGHT equ 100000h
DM_BITSPERPEL equ 40000h
CDS_FULLSCREEN equ 4h
devMode DEVMODEA <>

; Rectangle
SM_CXSCREEN equ 0
SM_CYSCREEN equ 1
windowRect RECT <0, 0, 0, 0>

; Pixel format descriptor
PFD_DRAW_TO_WINDOW equ 4h
PFD_SUPPORT_OPENGL equ 20h
PFD_DOUBLEBUFFER equ 1h
PFD_TYPE_RGBA equ 0
PFD_MAIN_PLANE equ 0
windowTitle db "Asteroids", 0
WS_OVERLAPPED equ 0C00000h
WS_SYSMENU equ 80000h
WS_CAPTION equ 0C00000h
WS_MINIMIZEBOX equ 20000h
WS_OVERLAPPEDWINDOW equ 0C00000h or 80000h or 40000h or 20000h or 10000h
WS_EX_APPWINDOW equ 40000h
WS_EX_WINDOWEDGE equ 100h
WS_POPUP equ 80000000h
WS_EX_APPWINDOW equ 40000h
dwStyle equ WS_OVERLAPPED or WS_SYSMENU or WS_CAPTION or WS_MINIMIZEBOX
dwExStyle equ WS_EX_APPWINDOW or WS_EX_WINDOWEDGE
dwFullscreenStyle equ WS_POPUP;
dwExFullscreenStyle equ WS_EX_APPWINDOW;
WS_CLIPSIBLINGS equ 4000000h
WS_CLIPCHILDREN equ 2000000h
pfd PIXELFORMATDESCRIPTOR <0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>

; Common
DEG2RAN dd 0.0174532925199433
FLOAT_SIGN_MASK equ 80000000h
RAND_FLOAT_RANGE equ 1000
SW_NORMAL equ 1
SW_MAXIMIZE equ 3
PM_REMOVE equ 1h
WM_QUIT equ 12h
WM_CLOSE equ 10h
WM_PAINT equ 0fh
WM_KEYDOWN equ 100h
WM_KEYUP equ 101h
msg MESSAGE <>
PATH_SIZE equ 512
absolutePath db PATH_SIZE dup (0)
randSeed dd 0
configName db "Settings.cfg", 0
readingMode db "r", 0
readConfig db "Fullscreen: %hhd Width: %hu Height: %hu Sound: %hhd", 0
MS2SEC dd 0.001
deltaTime dd 0
lastFrameTime dd 0

; Keys
KEY_ESCAPE equ 1Bh
KEY_SPACE equ 20h
KEY_LEFT equ 25h
KEY_UP equ 26h
KEY_RIGHT equ 27h
KEY_DOWN equ 28h
keys byte 256 dup (0)
keysPressed byte 256 dup (0)

; OpenGL
GL_DEPTH_TEST equ 0B71h
GL_LEQUAL equ 0203h
GL_PERSPECTIVE_CORRECTION_HINT equ 0C50h
GL_NICEST equ 1102h
GL_SMOOTH equ 1D01h
GL_SCISSOR_TEST equ 0c11h
GL_MODELVIEW equ 1700h
GL_PROJECTION equ 1701h
GL_COLOR_BUFFER_BIT equ 4000h
GL_DEPTH_BUFFER_BIT equ 100h
GL_CLEAR_DEPTH_BUFFER dd 1.0
GL_POINTS equ 0h
GL_LINES equ 1h
GL_LINE_STRIP equ 3h
GL_LINE_LOOP equ 2h
GL_NEAR dq 0.0
GL_FAR dq 1.0
TEXT_COLOR_R dd 1.0
TEXT_COLOR_G dd 1.0
TEXT_COLOR_B dd 1.0
BACKGROUND_COLOR_R dd 0.0
BACKGROUND_COLOR_G dd 0.0
BACKGROUND_COLOR_B dd 0.0
BACKGROUND_COLOR_A dd 1.0

; SHIP
SHIP_MOVE_SPEED dd 2.5
SHIP_ROTATION_SPEED dd 100.0
SHIP_FORWARD_SIZE dd 15
SHIP_BACK_SIZE dd 5
SHIP_BACKSIDE_SIZE dd 15
SHIP_SIDE_SIZE dd 10
SHIP_PLUME_SIZE dd 20
SHIP_PLUME_SIDE_SIZE dd 5
SHIP_THICKNESS dd 3
SHIP_BOUNDARY equ 15
SHIP_COLOR_R dd 1.0
SHIP_COLOR_G dd 1.0
SHIP_COLOR_B dd 1.0
SHIP_PLUME_COLOR_R dd 1.0
SHIP_PLUME_COLOR_G dd 0.75
SHIP_PLUME_COLOR_B dd 0.0
ship SHIP <0, 1>

; Asteroids
ASTEROID_MAX_SPEED dd 250
ASTEROID_MAX_ROTATION_SPEED dd 150.0
ASTEROID_THICKNESS dd 4
ASTEROID_COLOR_R dd 1.0
ASTEROID_COLOR_G dd 1.0
ASTEROID_COLOR_B dd 1.0
ASTEROID_BIG equ 0
ASTEROID_MIDDLE equ 1
ASTEROID_SMALL equ 2
ASTEROID_BIG_SIZE equ 40
ASTEROID_MIDDLE_SIZE equ 25
ASTEROID_SMALL_SIZE equ 12
ASTEROIDS_ON_START equ 3
ASTEROIDS_ON_RESTART dd 3
MAX_BIG_ASTEROIDS equ 10
MAX_ASTEROIDS equ MAX_BIG_ASTEROIDS * 2 * 3
asteroids ASTEROID MAX_ASTEROIDS dup ({0, 0.0, 0.0})

; Bullets
BULLET_SPEED dd 500.0
BULLET_SIZE dd 3
MAX_BULLETS equ 30
bullets BULLET MAX_BULLETS dup ({0})

; Effects
EFFECT_MAX_SPEED dd 80.0
EFFECT_TIME dd 1.5
EFFECT_SIZE dd 2
EFFECT_COLOR_R dd 1.0
EFFECT_COLOR_G dd 1.0
EFFECT_COLOR_B dd 1.0
MAX_EFFECTS equ MAX_ASTEROIDS + 1
effects WRAPPER_EFFECT MAX_EFFECTS dup ({})

NUMERAL_WIDTH equ 10
NUMERAL_HEIGHT equ 20
SCORE dd 0

numDisplayes NUMDISPLAY 10 DUP ( \
{1, 1, 1, 0, 1, 1, 1},
{0, 0, 1, 0, 0, 1, 0},
{1, 0, 1, 1, 1, 0, 1},
{1, 0, 1, 1, 0, 1, 1},
{0, 1, 1, 1, 0, 1, 0},
{1, 1, 0, 1, 0, 1, 1},
{1, 1, 0, 1, 1, 1, 1},
{1, 0, 1, 0, 0, 1, 0},
{1, 1, 1, 1, 1, 1, 1},
{1, 1, 1, 1, 0, 1, 1})

; Sound - Unfortunately, PlaySound doesn't support mixing sounds
SOUND_ENABLED byte 1
SND_FILENAME equ 20000h
SND_ASYNC equ 1h
SND_NODEFAULT equ 2h
SND_FLAGS equ SND_FILENAME or SND_ASYNC or SND_NODEFAULT
rocketEngine byte "Sounds\RocketEngine.wav", 0
blaster byte "Sounds\Blaster.wav", 0
shipExplosion byte "Sounds\ShipExplosion.wav", 0
asteroidExplosion byte "Sounds\AsteroidExplosion.wav", 0
rocketEnginePath byte PATH_SIZE dup (0)
blasterPath byte PATH_SIZE dup (0)
shipExplosionPath byte PATH_SIZE dup (0)
asteroidExplosionPath byte PATH_SIZE dup (0)

; Error messages
errorTitle db "An error occurred!", 0
registerClassError db "Could not register the window class!", 0
createWindowError db "Could not create a window!", 0
getDCError db "Could not get the device context!", 0
choosePFDError db "Could not choose the pixel format!", 0
setPFDError db "Could not set the pixel format context!", 0
createRCError db "Could not create a rendering context!", 0
makeCurrentRCError db "Could not make the current calling rendering context!", 0
initRendererError db "Could not initialize renderer!", 0
resetCurrentRCError db "Could not reset the current calling rendering context!", 0
deleteRCError db "Could not delete the rendering context!", 0
releaseDCError db "Could not release the device context!", 0
destroyWindowError db "Could not destroy the window!", 0
unregisterClassError db "Could not unregister the window class!", 0

.code

;================================================
;   WinMainCRTStartup
;================================================
WinMainCRTStartup proc
        local file:dq
        sub rsp, 28h

        ; Gets the absolute path of sound files
        xor rcx, rcx
        lea rdx, absolutePath
        mov r8, PATH_SIZE
        call GetModuleFileNameA
        lea rcx, absolutePath
        mov rdx, '\\'
        call strrchr
        xor cx, cx
        mov [rax + 1], cx
        lea rcx, rocketEnginePath
        lea rdx, absolutePath
        call strcat
        lea rcx, rocketEnginePath
        lea rdx, rocketEngine
        call strcat
        lea rcx, blasterPath
        lea rdx, absolutePath
        call strcat
        lea rcx, blasterPath
        lea rdx, blaster
        call strcat
        lea rcx, shipExplosionPath
        lea rdx, absolutePath
        call strcat
        lea rcx, shipExplosionPath
        lea rdx, shipExplosion
        call strcat
        lea rcx, asteroidExplosionPath
        lea rdx, absolutePath
        call strcat
        lea rcx, asteroidExplosionPath
        lea rdx, asteroidExplosion
        call strcat

        ; Reads config from the disk
        lea rcx, configName
        lea rdx, readingMode
        call fopen
        mov file, rax
        test rax, rax
        jz configNotFound
        lea rax, SOUND_ENABLED
        push rax
        lea rax, WINDOW_HEIGHT
        push rax
        lea r9, WINDOW_WIDTH
        lea r8, FULLSCREEN
        lea rdx, readConfig
        mov rcx, file
        sub rsp, 20h
        call fscanf
        add rsp, 30h
configNotFound:

        ; Initializes the game
        call InitWindow
        test rax, rax
        jnz kill
        mov al, FULLSCREEN
        test al, al
        mov rdx, SW_MAXIMIZE
        jnz @f
        mov rdx, SW_NORMAL
@@:     mov rcx, hWnd
        call ShowWindow
        mov rcx, hWnd
        call SetForegroundWindow
        mov rcx, hWnd
        call SetFocus
        mov rcx, hWnd
        call UpdateWindow
        mov rcx, 1
        call SetCursor
        call RestartGame
        call timeGetTime
        cvtsi2ss xmm0, eax
        movss lastFrameTime, xmm0

mainLoop:
        lea rcx, msg
        xor rdx, rdx
        xor r8, r8
        xor r9, r9
        push PM_REMOVE
        sub rsp, 20h
        call PeekMessageA
        add rsp, 28h
        test rax, rax
        jz update
        mov eax, msg.message
        cmp eax, WM_QUIT
        jne @f
        jmp kill
@@:     lea rcx, msg
        call TranslateMessage
        lea rcx, msg
        call DispatchMessageA
        jmp mainLoop
update: call Update
        call Draw
        ; Calculates delta time
        call timeGetTime
        cvtsi2ss xmm0, eax
        movss xmm2, xmm0
        movss xmm1, lastFrameTime
        subss xmm0, xmm1
        movss lastFrameTime, xmm2
        movss xmm1, MS2SEC
        mulss xmm0, xmm1
        movss deltaTime, xmm0
        jmp mainLoop

kill:   call KillWindow
        xor rcx, rcx
        call ExitProcess
        add rsp, 28h
        ret
WinMainCRTStartup endp

;================================================
;   Update
;================================================
Update proc
        sub rsp, 28h

        ; Quits the game when pressing escape key
        lea rax, keysPressed
        mov al, [rax + KEY_ESCAPE]
        test al, al
        je @f
        xor rcx, rcx
        call ExitProcess
        add rsp, 28h
        ret
@@:

        ; Restarts the game when the ship is destroyed and pressing space key
        mov al, ship.destroyed
        test al, al
        jz @f
        lea rax, keysPressed
        mov al, byte ptr [rax + KEY_SPACE]
        test al, al
        je @f
        call RestartGame
        jmp skip
@@:

        ; Resets the game automatically if there are no asteroids left
        xor rcx, rcx
@@:     cmp rcx, MAX_ASTEROIDS 
        jge @f
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        mov dl, (ASTEROID ptr [rdx + rax]).active
        add rcx, 1
        test dl, dl
        jz @b
        jmp noRestartNeeded
@@:     inc ASTEROIDS_ON_RESTART
        cmp ASTEROIDS_ON_RESTART, MAX_BIG_ASTEROIDS
        jle @f
        mov ASTEROIDS_ON_RESTART, MAX_BIG_ASTEROIDS
@@:     call RestartGame
noRestartNeeded:

        ; Jumps over if the ship is destroyed
        mov al, ship.destroyed
        test al, al
        jnz noShip

        ; Updates the ship
        mov ship.accelerating, 0
        movss xmm1, [ship.vel.x]
        movss xmm2, deltaTime
        mulss xmm1, xmm2
        movss xmm0, [ship.pos.x]
        addss xmm0, xmm1
        movss [ship.pos.x], xmm0
        movss xmm1, [ship.vel.y]
        movss xmm2, deltaTime
        mulss xmm1, xmm2
        movss xmm0, [ship.pos.y]
        addss xmm0, xmm1
        movss [ship.pos.y], xmm0
        lea rcx, ship.pos
        mov rdx, SHIP_BOUNDARY
        call WarpPosition

        ; Rotates the ship to the left when pressing left key
        lea rax, keys
        mov al, byte ptr [rax + KEY_LEFT]
        cmp al, 1
        jne @f
        movss xmm0, ship.rot
        movss xmm1, SHIP_ROTATION_SPEED
        movss xmm2, deltaTime
        mulss xmm1, xmm2
        subss xmm0, xmm1
        movss [ship.rot], xmm0
@@:

        ; Rotates the ship to the right when pressing right key
        lea rax, keys
        mov al, byte ptr [rax + KEY_RIGHT]
        cmp al, 1
        jne @f
        movss xmm0, ship.rot
        movss xmm1, SHIP_ROTATION_SPEED
        movss xmm2, deltaTime
        mulss xmm1, xmm2
        addss xmm0, xmm1
        movss [ship.rot], xmm0
@@:

        ; Accelerates the ship forward when pressing up key
        lea rax, keys
        mov al, byte ptr [rax + KEY_UP]
        cmp al, 1
        jne @f
        mov ship.accelerating, 1
        movss xmm0, DEG2RAN
        movss xmm1, [ship.rot]
        mulss xmm0, xmm1
        call sinf
        movss xmm1, SHIP_MOVE_SPEED
        mulss xmm0, xmm1
        movss xmm1, [ship.vel.x]
        addss xmm1, xmm0
        movss [ship.vel.x], xmm1
        movss xmm0, DEG2RAN
        movss xmm1, [ship.rot]
        mulss xmm0, xmm1
        call cosf
        movss xmm1, SHIP_MOVE_SPEED
        mulss xmm0, xmm1
        movss xmm1, [ship.vel.y]
        addss xmm1, xmm0
        movss [ship.vel.y], xmm1
        ; Plays rocket engine sound if enabled
        ;mov al, SOUND_ENABLED
        ;test al, al
        ;jz @f
        ;lea rcx, rocketEnginePath
        ;mov rdx, 0
        ;mov r8d, SND_FLAGS
        ;call PlaySound
@@:

        ; Shoots bullets when pressing space key
        lea rax, keysPressed
        mov al, byte ptr [rax + KEY_SPACE]
        cmp al, 1
        jne shootingEnd
        ; Checks if there is an inactive bullet in bullets array
        xor rcx, rcx
bulletsWhile:
        cmp rcx, MAX_BULLETS
        jge shootingEnd
        mov rax, sizeof BULLET
        mul rcx
        lea rdx, bullets
        mov dl, (BULLET ptr [rdx + rax]).active
        test dl, dl
        jz @f
        add rcx, 1
        jmp bulletsWhile
        ; If so, makes it active and sets its proper position and speed
@@:     movss xmm0, DEG2RAN
        movss xmm1, [ship.rot]
        mulss xmm0, xmm1
        call sinf
        mov rax, sizeof BULLET
        mul rcx
        lea rdx, bullets
        movss xmm1, BULLET_SPEED
        mulss xmm1, xmm0
        movss xmm2, ship.vel.x
        addss xmm1, xmm2
        movss (BULLET ptr [rdx + rax]).vel.x, xmm1
        cvtsi2ss xmm1, SHIP_FORWARD_SIZE
        mulss xmm1, xmm0
        movss xmm0, ship.pos.x
        addss xmm0, xmm1
        movss (BULLET ptr [rdx + rax]).pos.x, xmm0
        movss xmm0, DEG2RAN
        movss xmm1, [ship.rot]
        mulss xmm0, xmm1
        call cosf
        mov rax, sizeof BULLET
        mul rcx
        lea rdx, bullets
        movss xmm1, BULLET_SPEED
        mulss xmm1, xmm0
        movss xmm2, ship.vel.y
        addss xmm1, xmm2
        movss (BULLET ptr [rdx + rax]).vel.y, xmm1
        cvtsi2ss xmm1, SHIP_FORWARD_SIZE
        mulss xmm1, xmm0
        movss xmm0, ship.pos.y
        addss xmm0, xmm1
        movss (BULLET ptr [rdx + rax]).pos.y, xmm0
        mov (BULLET ptr [rdx + rax]).active, 1
        ; Plays blaster sound if enabled
        mov al, SOUND_ENABLED
        test al, al
        jz @f
        lea rcx, blasterPath
        mov rdx, 0
        mov r8d, SND_FLAGS
        call PlaySound
@@:
shootingEnd:
noShip:

        ; Updates bullets
        xor rcx, rcx
bulletsFor:
        cmp rcx, MAX_BULLETS
        jge bulletsForEnd
        mov rax, sizeof BULLET
        mul rcx
        lea rdx, bullets
        mov dl, (BULLET ptr [rdx + rax]).active
        test dl, dl
        jz bulletsForContinue
        ; Updates bullet positions
        lea rdx, bullets
        movss xmm1, (BULLET ptr [rdx + rax]).vel.x
        movss xmm2, deltaTime
        mulss xmm1, xmm2
        movss xmm0, (BULLET ptr [rdx + rax]).pos.x
        addss xmm0, xmm1
        movss (BULLET ptr [rdx + rax]).pos.x, xmm0
        movss xmm1, (BULLET ptr [rdx + rax]).vel.y
        movss xmm2, deltaTime
        mulss xmm1, xmm2
        movss xmm0, (BULLET ptr [rdx + rax]).pos.y
        addss xmm0, xmm1
        movss (BULLET ptr [rdx + rax]).pos.y, xmm0
        ; Checks whether a bullet is out of the screen or not
        lea rdx, bullets
        mov rax, sizeof BULLET
        push rdx
        mul rcx
        pop rdx
        ; Left border
        movss xmm0, (BULLET ptr [rdx + rax]).pos.x
        xorps xmm1, xmm1
        comiss xmm0, xmm1
        jb @f
        ; Right border
        movss xmm0, (BULLET ptr [rdx + rax]).pos.x
        push rax
        mov eax, WINDOW_WIDTH
        cvtsi2ss xmm1, eax
        pop rax
        comiss xmm0, xmm1
        ja @f
        ; Upper border
        movss xmm0, (BULLET ptr [rdx + rax]).pos.y
        xorps xmm1, xmm1
        comiss xmm0, xmm1
        jb @f
        ; Bottom border
        movss xmm0, (BULLET ptr [rdx + rax]).pos.y
        push rax
        mov eax, WINDOW_HEIGHT
        cvtsi2ss xmm1, eax
        pop rax
        comiss xmm0, xmm1
        ja @f
        jmp bulletsForContinue
        ; If yes, destroys it
@@:     push rcx
        lea rcx, BULLET ptr [rdx + rax]
        mov rdx, 0
        mov r8, sizeof BULLET
        sub rsp, 28h
        call memset
        add rsp, 28h
        pop rcx
bulletsForContinue:
        inc rcx
        jmp bulletsFor
bulletsForEnd:

        ; Updates asteroids
        push rbx
        xor rcx, rcx
asteroidsFor:
        cmp rcx, MAX_ASTEROIDS
        jge asteroidsForEnd
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        mov dl, (ASTEROID ptr [rdx + rax]).active
        test dl, dl
        jz asteroidsForContinue
        ; Updates rotation and position
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        mov ax, (ASTEROID ptr [rdx + rax]).sizeType
        cmp ax, ASTEROID_BIG
        jne @f
        mov rbx, ASTEROID_BIG_SIZE
        jmp sizeChosen
@@:
        cmp ax, ASTEROID_MIDDLE
        jne @f
        mov rbx, ASTEROID_MIDDLE_SIZE
        jmp sizeChosen
@@:
        cmp ax, ASTEROID_SMALL
        jne @f
        mov rbx, ASTEROID_SMALL_SIZE
        jmp sizeChosen
@@:
sizeChosen:
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        movss xmm0, (ASTEROID ptr [rdx + rax]).rot
        movss xmm1, (ASTEROID ptr [rdx + rax]).rotSpeed
        movss xmm2, deltaTime
        mulss xmm1, xmm2
        addss xmm0, xmm1
        movss (ASTEROID ptr [rdx + rax]).rot, xmm0
        movss xmm1, (ASTEROID ptr [rdx + rax]).vel.x
        movss xmm2, deltaTime
        mulss xmm1, xmm2
        movss xmm0, (ASTEROID ptr [rdx + rax]).pos.x
        addss xmm0, xmm1
        movss (ASTEROID ptr [rdx + rax]).pos.x, xmm0
        movss xmm1, (ASTEROID ptr [rdx + rax]).vel.y
        movss xmm2, deltaTime
        mulss xmm1, xmm2
        movss xmm0, (ASTEROID ptr [rdx + rax]).pos.y
        addss xmm0, xmm1
        movss (ASTEROID ptr [rdx + rax]).pos.y, xmm0
        ; Warps position
        push rcx
        sub rsp, 20h
        lea rcx, (ASTEROID ptr [rdx + rax]).pos
        mov rdx, rbx
        call WarpPosition
        add rsp, 20h
        pop rcx
        ; Destroys the ship if it collides with an asteroid
        mov al, ship.destroyed
        test al, al
        jnz shipNotCollided
        push rcx
        sub rsp, 20h
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        lea rcx, (ASTEROID ptr [rdx + rax]).pos
        mov rdx, rbx
        lea r8, ship.pos
        mov r9, SHIP_BOUNDARY
        call IsCollided
        add rsp, 20h
        pop rcx
        test rax, rax
        jz shipNotCollided
        mov ship.destroyed, 1
        push rcx
        lea rcx, ship.pos
        sub rsp, 20h
        call SpawnParticle
        ; Plays ship explosion sound if enabled
        mov al, SOUND_ENABLED
        test al, al
        jz @f
        lea rcx, shipExplosionPath
        mov rdx, 0
        mov r8d, SND_FLAGS
        call PlaySound
@@:     add rsp, 20h
        pop rcx
shipNotCollided:
        ; Iterates over bullets to check for collisions
        push rcx
        xor rcx, rcx
asteroidsBulletsFor:
        cmp rcx, MAX_BULLETS
        jge asteroidsBulletsForEnd
        mov rax, sizeof BULLET
        mul rcx
        lea rdx, bullets
        mov dl, (BULLET ptr [rdx + rax]).active
        test dl, dl
        jz asteroidsBulletsForContinue
        ; Checks for collisions with an asteroid
        push rcx
        sub rsp, 28h
        mov rax, sizeof BULLET
        mul rcx
        lea rdx, bullets
        lea rcx, (BULLET ptr [rdx + rax]).pos
        mov edx, BULLET_SIZE
        push rcx
        push rdx
        mov rcx, [rsp + 40h]
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        lea r8, (ASTEROID ptr [rdx + rax]).pos
        mov r9, rbx
        pop rdx
        pop rcx
        call IsCollided
        add rsp, 28h
        pop rcx
        test rax, rax
        jz notCollided
        ; If collided
        push rcx
        sub rsp, 20h
        ; Destroys the bullet
        mov rax, sizeof BULLET
        mul rcx
        lea rdx, bullets
        lea rcx, (BULLET ptr [rdx + rax])
        mov rdx, 0
        mov r8, sizeof BULLET
        call memset
        ; Breaks up asteroids into smaller pieces
        push r12
        mov rcx, [rsp + 30h]
        mov rax, sizeof ASTEROID
        mul rcx
        push rbx
        lea rbx, asteroids
        add rbx, rax
        mov ax, (ASTEROID ptr [rbx]).sizeType
        ; Scoring
        push rbx
        mov ebx, SCORE
        add ebx, eax
        inc ebx
        mov SCORE, ebx
        pop rbx
        ; !Scoring
        inc ax
        cmp ax, ASTEROID_SMALL
        jg breakUpDone
        mov r12w, ax
        mov cx, ax
breakUp:
        cmp cx, 0
        jl breakUpDone
        push rcx
        sub rsp, 28h
        lea rcx, (ASTEROID ptr [rbx]).pos 
        xor rdx, rdx
        mov dx, r12w
        call SpawnAsteroid
        add rsp, 28h
        pop rcx
        dec rcx
        jmp breakUp
breakUpDone:
        pop rbx
        pop r12
        ; Destroys the asteroid
        mov rcx, [rsp + 28h]
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        mov r12, rax
        lea rcx, (ASTEROID ptr [rdx + r12]).pos
        call SpawnParticle
        lea rdx, asteroids
        lea rcx, (ASTEROID ptr [rdx + r12])
        xor rdx, rdx
        mov r8, sizeof ASTEROID
        call memset
        lea rdx, asteroids
        mov (ASTEROID ptr [rdx + r12]).active, 0
        ; Plays asteroid explosion sound if enabled
        ;mov al, SOUND_ENABLED
        ;test al, al
        ;jz @f
        ;lea rcx, asteroidExplosionPath
        ;xor rdx, rdx
        ;mov r8d, SND_FLAGS
        ;call PlaySound
;@@:
        add rsp, 20h
        pop rcx
notCollided:
asteroidsBulletsForContinue:
        inc rcx
        jmp asteroidsBulletsFor
asteroidsBulletsForEnd:
        pop rcx
asteroidsForContinue:
        inc rcx
        jmp asteroidsFor
asteroidsForEnd:
        pop rbx
        
        ; Updates effects
        xor rcx, rcx
effectsFor:
        cmp rcx, MAX_EFFECTS
        jge effectsEnd
        mov rax, sizeof WRAPPER_EFFECT
        mul rcx
        lea rdx, effects
        ; Checks if an effect has life time left
        movss xmm0, (WRAPPER_EFFECT ptr [rdx + rax]).data.time
        xorps xmm1, xmm1
        comiss xmm0, xmm1
        ja @f
        add rcx, 1
        jmp effectsFor
        ; If so, decrease its lifetime by deltaTime
@@:     push rcx
        push r12
        push r13
        mov rax, sizeof WRAPPER_EFFECT
        mul rcx
        lea rdx, effects
        movss xmm0, (WRAPPER_EFFECT ptr [rdx + rax]).data.time
        subss xmm0, deltaTime
        movss (WRAPPER_EFFECT ptr [rdx + rax]).data.time, xmm0
        ; Then, updates its particle positions
        lea r12, (WRAPPER_EFFECT ptr [rdx + rax]).data.vel
        lea r13, (WRAPPER_EFFECT ptr [rdx + rax]).data.pos
        xor rcx, rcx
particlesFor:
        cmp rcx, MAX_PARTICLES
        jge particlesForEnd
        mov rax, sizeof POINTF
        mul rcx
        movss xmm1, (POINTF ptr [r12 + rax]).x
        movss xmm2, deltaTime
        mulss xmm1, xmm2
        movss xmm0, (POINTF ptr [r13 + rax]).x
        addss xmm0, xmm1
        movss (POINTF ptr [r13 + rax]).x, xmm0
        movss xmm1, (POINTF ptr [r12 + rax]).y
        movss xmm2, deltaTime
        mulss xmm1, xmm2
        movss xmm0, (POINTF ptr [r13 + rax]).y
        addss xmm0, xmm1
        movss (POINTF ptr [r13 + rax]).y, xmm0
        inc rcx
        jmp particlesFor
particlesForEnd:
        pop r13
        pop r12
        pop rcx
        inc rcx
        jmp effectsFor
effectsEnd:

        ; Resets pressed key states
skip:   lea rcx, keysPressed
        xor rdx, rdx
        mov r8, sizeof keysPressed
        call memset

        add rsp, 28h
        ret
Update endp

;================================================
;   IsCollided
;
;   rcx = pos1 - A pointer to POINTF structure
;   rdx = size1 - Size of boundary
;   r8 = pos2 - A pointer to POINTF structure 
;   r9 = size2 - Size of boundary 
;
;   Returns 1 if collided, otherwise return 0
;================================================
IsCollided proc
        sub rsp, 28h
        xor rax, rax

        ; Left horizontal side < right horizontal side
        movss xmm0, (POINTF ptr [rcx]).x
        cvtsi2ss xmm1, rdx
        subss xmm0, xmm1
        movss xmm1, (POINTF ptr [r8]).x
        cvtsi2ss xmm2, r9
        addss xmm1, xmm2
        comiss xmm0, xmm1
        jae @f

        ; Right horizontal side > left horizontal side
        movss xmm0, (POINTF ptr [rcx]).x
        cvtsi2ss xmm1, rdx
        addss xmm0, xmm1
        movss xmm1, (POINTF ptr [r8]).x
        cvtsi2ss xmm2, r9
        subss xmm1, xmm2
        comiss xmm0, xmm1
        jbe @f

        ; Bottom vertical side < upper vertical side
        movss xmm0, (POINTF ptr [rcx]).y
        cvtsi2ss xmm1, rdx
        subss xmm0, xmm1
        movss xmm1, (POINTF ptr [r8]).y
        cvtsi2ss xmm2, r9
        addss xmm1, xmm2
        comiss xmm0, xmm1
        jae @f

        ; Upper vertical side > bottom vertical side
        movss xmm0, (POINTF ptr [rcx]).y
        cvtsi2ss xmm1, rdx
        addss xmm0, xmm1
        movss xmm1, (POINTF ptr [r8]).y
        cvtsi2ss xmm2, r9
        subss xmm1, xmm2
        comiss xmm0, xmm1
        jbe @f

        mov rax, 1
@@:     add rsp, 28h
        ret
IsCollided endp

;================================================
;   WarpPosition
;
;   rcx = pos - A pointer to POINTF structure
;   rdx = size - Size of boundary
;================================================
WarpPosition proc
        sub rsp, 28h

        ; From the left edge to the right edge of the screen
        cvtsi2ss xmm2, rdx
        movss xmm0, (POINTF ptr [rcx]).x
        addss xmm0, xmm2
        xorps xmm1, xmm1
        comiss xmm0, xmm1
        ja @f
        mov eax, WINDOW_WIDTH
        cvtsi2ss xmm0, eax
        addss xmm0, xmm2
        movss (POINTF ptr [rcx]).x, xmm0
        jmp horWarpDone
@@:

        ; From the right edge to the left edge of the screen
        cvtsi2ss xmm2, rdx
        movss xmm0, (POINTF ptr [rcx]).x
        subss xmm0, xmm2
        mov eax, WINDOW_WIDTH
        cvtsi2ss xmm1, eax
        comiss xmm0, xmm1
        jb @f
        xorps xmm0, xmm0
        subss xmm0, xmm2
        movss (POINTF ptr [rcx]).x, xmm0
        jmp horWarpDone
@@:
horWarpDone:

        ; From the upper edge to the bottom edge of the screen
        cvtsi2ss xmm2, rdx
        movss xmm0, (POINTF ptr [rcx]).y
        subss xmm0, xmm2
        mov eax, WINDOW_HEIGHT
        cvtsi2ss xmm1, eax
        comiss xmm0, xmm1
        jb @f
        xorps xmm0, xmm0
        subss xmm0, xmm2
        movss (POINTF ptr [rcx]).y, xmm0
        jmp verWarpDone
@@:

        ; From the bottom edge to the upper edge of the screen
        cvtsi2ss xmm2, rdx
        movss xmm0, (POINTF ptr [rcx]).y
        addss xmm0, xmm2
        xorps xmm1, xmm1
        comiss xmm0, xmm1
        ja @f
        mov eax, WINDOW_HEIGHT
        cvtsi2ss xmm0, eax
        addss xmm0, xmm2
        movss (POINTF ptr [rcx]).y, xmm0
        jmp verWarpDone
@@:
verWarpDone:

        add rsp, 28h
        ret
WarpPosition endp

;================================================
;   SpawnAsteroid
;
;   rcx = pos - base address of POINTF
;   rdx = type - An asteroid type (0-2)
;================================================
SpawnAsteroid proc
        push rbp
        lea rbp, [rsp + 8h]
        mov [rbp + 8h], rcx
        mov [rbp + 10h], rdx
        sub rsp, 20h

        ; Places asteroids randomly on the screen
        xor rcx, rcx
asteroidsFor:
        cmp rcx, MAX_ASTEROIDS
        jge asteroidsForEnd
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        mov al, (ASTEROID ptr [rdx + rax]).active
        test al, al
        jz @f
        inc rcx
        jmp asteroidsFor
        ; Generates rotation
@@:     push rcx
        xor rcx, rcx
        mov rdx, 360
        sub rsp, 28h
        call Rand
        add rsp, 28h
        pop rcx
        cvtsi2ss xmm0, eax
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        movss (ASTEROID ptr [rdx + rax]).rot, xmm0
        ; Generates rotation speed
        push rcx
        mov ecx, RAND_FLOAT_RANGE
        neg ecx
        mov edx, RAND_FLOAT_RANGE
        sub rsp, 28h
        call Rand
        add rsp, 28h
        cvtsi2ss xmm0, eax
        mov eax, RAND_FLOAT_RANGE
        cvtsi2ss xmm1, eax
        divss xmm0, xmm1
        movss xmm1, ASTEROID_MAX_ROTATION_SPEED
        mulss xmm0, xmm1
        pop rcx
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        movss (ASTEROID ptr [rdx + rax]).rotSpeed, xmm0
        ; Sets position
        push rcx
        mov rcx, [rbp + 8h]
        movss xmm0, (POINTF ptr [rcx]).x
        movss (ASTEROID ptr [rdx + rax]).pos.x, xmm0
        movss xmm0, (POINTF ptr [rcx]).y
        movss (ASTEROID ptr [rdx + rax]).pos.y, xmm0
        pop rcx
        ; Generates the x-coordinate velocity
        push rcx
@@:     mov ecx, ASTEROID_MAX_SPEED
        neg ecx
        mov edx, ASTEROID_MAX_SPEED
        sub rsp, 28h
        call Rand
        add rsp, 28h
        test eax, eax
        jz @b
        pop rcx
        cvtsi2ss xmm0, eax
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        movss (ASTEROID ptr [rdx + rax]).vel.x, xmm0
        ; Generates the y-coordinate velocity
        push rcx
@@:     mov ecx, ASTEROID_MAX_SPEED
        neg ecx
        mov edx, ASTEROID_MAX_SPEED
        sub rsp, 28h
        call Rand
        add rsp, 28h
        test eax, eax
        jz @b
        pop rcx
        cvtsi2ss xmm0, eax
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        movss (ASTEROID ptr [rdx + rax]).vel.y, xmm0
        mov cx, [rbp + 10h]
        mov (ASTEROID ptr [rdx + rax]).sizeType, cx
        mov (ASTEROID ptr [rdx + rax]).active, 1
asteroidsForEnd:

        add rsp, 20h
        pop rbp
        ret
SpawnAsteroid endp

;================================================
;   SpawnParticle
;
;   rcx = pos - base address of POINTF
;================================================
SpawnParticle proc
        push rbp
        lea rbp, [rsp + 8h]
        mov [rbp + 8h], rcx
        sub rsp, 20h
        
        ; Checks if there is an inactive effect in effects array
        xor rcx, rcx
effectsFor:
        cmp rcx, MAX_EFFECTS
        jge effectsForEnd
        mov rax, sizeof WRAPPER_EFFECT
        mul rcx
        lea rdx, effects
        movss xmm0, (WRAPPER_EFFECT ptr [rdx + rax]).data.time
        xorps xmm1, xmm1
        comiss xmm0, xmm1
        jbe @f
        add rcx, 1
        jmp effectsFor
        ; If so, uses the inactive effect as a new effect
@@:     push rcx
        push r12
        push r13
        mov rax, sizeof WRAPPER_EFFECT
        mul rcx
        lea rdx, effects
        movss xmm0, EFFECT_TIME
        movss (WRAPPER_EFFECT ptr [rdx + rax]).data.time, xmm0
        lea r12, (WRAPPER_EFFECT ptr [rdx + rax]).data.vel
        lea r13, (WRAPPER_EFFECT ptr [rdx + rax]).data.pos
        xor rcx, rcx
particlesFor:
        cmp rcx, MAX_PARTICLES
        jge particlesForEnd
        ; Generates the x-coordinate velocity
        push rcx
        mov ecx, RAND_FLOAT_RANGE
        neg ecx
        mov edx, RAND_FLOAT_RANGE
        sub rsp, 28h
        call Rand
        add rsp, 28h
        cvtsi2ss xmm0, eax
        mov eax, RAND_FLOAT_RANGE
        cvtsi2ss xmm1, eax
        divss xmm0, xmm1
        movss xmm1, EFFECT_MAX_SPEED
        mulss xmm0, xmm1
        pop rcx
        mov rax, sizeof POINTF
        mul rcx
        movss (POINTF ptr [r12 + rax]).x, xmm0
        ; Generates the y-coordinate velocity
        push rcx
        mov ecx, RAND_FLOAT_RANGE
        neg ecx
        mov edx, RAND_FLOAT_RANGE
        sub rsp, 28h
        call Rand
        add rsp, 28h
        cvtsi2ss xmm0, eax
        mov eax, RAND_FLOAT_RANGE
        cvtsi2ss xmm1, eax
        divss xmm0, xmm1
        movss xmm1, EFFECT_MAX_SPEED
        mulss xmm0, xmm1
        pop rcx
        mov rax, sizeof POINTF
        mul rcx
        movss (POINTF ptr [r12 + rax]).y, xmm0
        ; Sets position to the first passed argument
        mov rax, sizeof POINTF
        mul rcx
        mov rdx, [rbp + 8h]
        movss xmm0, (POINTF ptr [rdx]).x
        movss (POINTF ptr [r13 + rax]).x, xmm0
        movss xmm0, (POINTF ptr [rdx]).y
        movss (POINTF ptr [r13 + rax]).y, xmm0
        inc rcx
        jmp particlesFor
particlesForEnd:
        pop r13
        pop r12
        pop rcx
effectsForEnd:

        add rsp, 20h
        pop rbp
        ret
SpawnParticle endp

;================================================
;   Draw
;================================================
Draw proc
        sub rsp, 28h
        
        ; Clears screen
        movd xmm0, [BACKGROUND_COLOR_R]
        movd xmm1, [BACKGROUND_COLOR_G]
        movd xmm2, [BACKGROUND_COLOR_B]
        movd xmm3, [BACKGROUND_COLOR_A]
        call glClearColor
        mov rcx, GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT
        call glClear

        ; Draws effects
        call glLoadIdentity
        mov eax, EFFECT_SIZE
        cvtsi2ss xmm0, eax
        call glPointSize
        mov rcx, GL_POINTS
        call glBegin
        xor rcx, rcx
effectsFor:
        cmp rcx, MAX_EFFECTS
        jge effectsForEnd
        mov rax, sizeof WRAPPER_EFFECT
        mul rcx
        lea rdx, effects
        ; Checks if an effect has life time left
        mov edx, (WRAPPER_EFFECT ptr [rdx + rax]).data.time
        test edx, edx
        jnz @f
        add rcx, 1
        jmp effectsFor
        ; if so, draws the effect
@@:     lea rdx, effects
        movss xmm4, (WRAPPER_EFFECT ptr [rdx + rax]).data.time
        movss xmm5, EFFECT_TIME
        divss xmm4, xmm5
        mov rdx, 1
        cvtsi2ss xmm5, rdx
        subss xmm5, xmm4
        movss xmm4, xmm5
        movd xmm0, [EFFECT_COLOR_R]
        movd xmm5, [BACKGROUND_COLOR_R]
        subss xmm5, xmm0
        mulss xmm5, xmm4
        addss xmm0, xmm5
        movd xmm1, [EFFECT_COLOR_G]
        movd xmm5, [BACKGROUND_COLOR_G]
        subss xmm5, xmm1
        mulss xmm5, xmm4
        addss xmm1, xmm5
        movd xmm2, [EFFECT_COLOR_B]
        movd xmm5, [BACKGROUND_COLOR_B]
        subss xmm5, xmm2
        mulss xmm5, xmm4
        addss xmm2, xmm5
        push rcx
        sub rsp, 28h
        call glColor3f
        add rsp, 28h
        pop rcx
        push rcx
        push r12
        ; Draws particles
        mov rax, sizeof WRAPPER_EFFECT
        mul rcx
        lea rdx, effects
        lea r12, (WRAPPER_EFFECT ptr [rdx + rax]).data.pos
        xor rcx, rcx
particlesFor:
        cmp rcx, MAX_PARTICLES
        jge particlesForEnd
        mov rax, sizeof POINTF
        mul rcx
        movss xmm0, (POINTF ptr [r12 + rax]).x
        movss xmm1, (POINTF ptr [r12 + rax]).y
        push rcx
        sub rsp, 28h
        call glVertex2f
        add rsp, 28h
        pop rcx
        inc rcx
        jmp particlesFor
particlesForEnd:
        pop r12
        pop rcx
        inc rcx
        jmp effectsFor
effectsForEnd:
        call glEnd

        ; Jumps over if the ship is destroyed
        mov al, ship.destroyed
        test al, al
        jnz noShip

        ; Sets up the ship parameters
        call glLoadIdentity
        movd xmm0, [SHIP_THICKNESS]
        call glLineWidth
        movss xmm0, [ship.pos.x]
        movss xmm1, [ship.pos.y]
        xorps xmm2, xmm2
        call glTranslatef
        movss xmm0, [ship.rot]
        xor rax, rax
        mov eax, FLOAT_SIGN_MASK
        movd xmm1, eax
        xorps xmm0, xmm1
        xorps xmm1, xmm1
        xorps xmm2, xmm2
        mov eax, 1
        cvtsi2ss xmm3, eax
        call glRotatef

        ; Draws the ship
        mov rcx, GL_LINE_LOOP
        call glBegin
        movd xmm0, [SHIP_COLOR_R]
        movd xmm1, [SHIP_COLOR_G]
        movd xmm2, [SHIP_COLOR_B]
        call glColor3f
        xorps xmm0, xmm0
        cvtsi2ss xmm1, [SHIP_FORWARD_SIZE]
        call glVertex2f
        cvtsi2ss xmm0, [SHIP_SIDE_SIZE]
        mov eax, SHIP_BACKSIDE_SIZE
        neg rax
        cvtsi2ss xmm1, eax
        call glVertex2f
        xorps xmm0, xmm0
        mov eax, SHIP_BACK_SIZE
        neg rax
        cvtsi2ss xmm1, eax
        call glVertex2f
        mov eax, SHIP_SIDE_SIZE
        neg rax
        cvtsi2ss xmm0, eax
        mov eax, SHIP_BACKSIDE_SIZE
        neg rax
        cvtsi2ss xmm1, eax
        call glVertex2f
        call glEnd

        ; Draws rocket engine plume
        cmp ship.accelerating, 1
        jne @f
        mov rcx, GL_LINE_STRIP
        call glBegin
        movd xmm0, [SHIP_PLUME_COLOR_R]
        movd xmm1, [SHIP_PLUME_COLOR_G]
        movd xmm2, [SHIP_PLUME_COLOR_B]
        call glColor3f
        mov eax, SHIP_PLUME_SIDE_SIZE
        neg rax
        cvtsi2ss xmm0, eax
        mov eax, SHIP_BACKSIDE_SIZE
        neg rax
        cvtsi2ss xmm1, eax
        call glVertex2f
        xorps xmm0, xmm0
        mov eax, SHIP_PLUME_SIZE
        neg rax
        cvtsi2ss xmm1, eax
        call glVertex2f
        cvtsi2ss xmm0, SHIP_PLUME_SIDE_SIZE
        mov eax, SHIP_BACKSIDE_SIZE
        neg rax
        cvtsi2ss xmm1, eax
        call glVertex2f
        call glEnd
@@:
noShip:

        ; Draws bullets
        call glLoadIdentity
        mov eax, BULLET_SIZE
        cvtsi2ss xmm0, eax
        call glPointSize
        mov rcx, GL_POINTS
        call glBegin
        movd xmm0, [SHIP_COLOR_R]
        movd xmm1, [SHIP_COLOR_G]
        movd xmm2, [SHIP_COLOR_B]
        call glColor3f
        xor rcx, rcx
bulletsFor:
        ; Checks if a bullet is active
        cmp rcx, MAX_BULLETS
        jge bulletsForEnd
        mov rax, sizeof BULLET
        mul rcx
        lea rdx, bullets
        mov dl, (BULLET ptr [rdx + rax]).active
        test dl, dl
        jnz @f
        inc rcx
        jmp bulletsFor
        ; If so, draws it
@@:     lea rdx, bullets
        movss xmm0, (BULLET ptr [rdx + rax]).pos.x
        movss xmm1, (BULLET ptr [rdx + rax]).pos.y
        push rcx
        sub rsp, 28h
        call glVertex2f
        add rsp, 28h
        pop rcx
        inc rcx
        jmp bulletsFor
bulletsForEnd:
        call glEnd

        ; Draws asteroids
        xor rcx, rcx
asteroidsFor:
        ; Checks if an asteroid is not destroyed
        cmp rcx, MAX_ASTEROIDS
        jge asteroidsForEnd
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        mov dl, (ASTEROID ptr [rdx + rax]).active
        test dl, dl
        jz asteroidsForContinue
        ; If so, draws it
        push rcx
        sub rsp, 28h
        call glLoadIdentity
        movd xmm0, [ASTEROID_THICKNESS]
        call glLineWidth
        add rsp, 28h
        pop rcx
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        push rcx
        sub rsp, 28h
        movss xmm0, (ASTEROID ptr [rdx + rax]).pos.x
        movss xmm1, (ASTEROID ptr [rdx + rax]).pos.y
        xorps xmm2, xmm2
        call glTranslatef
        add rsp, 28h
        pop rcx
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        push rcx
        sub rsp, 28h
        movss xmm0, (ASTEROID ptr [rdx + rax]).rot
        xor rax, rax
        mov eax, FLOAT_SIGN_MASK
        movd xmm1, eax
        xorps xmm0, xmm1
        xorps xmm1, xmm1
        xorps xmm2, xmm2
        mov eax, 1
        cvtsi2ss xmm3, eax
        call glRotatef
        mov rcx, GL_LINE_LOOP
        call glBegin
        movd xmm0, [ASTEROID_COLOR_R]
        movd xmm1, [ASTEROID_COLOR_G]
        movd xmm2, [ASTEROID_COLOR_B]
        call glColor3f
        mov rcx, [rsp + 28h]
        push rbx
        sub rsp, 28h
        mov rax, sizeof ASTEROID
        mul rcx
        lea rdx, asteroids
        mov ax, (ASTEROID ptr [rdx + rax]).sizeType
        cmp ax, ASTEROID_BIG
        jne @f
        mov rbx, ASTEROID_BIG_SIZE
        jmp sizeChosen
@@:
        cmp ax, ASTEROID_MIDDLE
        jne @f
        mov rbx, ASTEROID_MIDDLE_SIZE
        jmp sizeChosen
@@:
        cmp ax, ASTEROID_SMALL
        jne @f
        mov rbx, ASTEROID_SMALL_SIZE
        jmp sizeChosen
@@:
sizeChosen:
        xorps xmm0, xmm0
        mov rax, rbx
        cvtsi2ss xmm1, rax
        call glVertex2f
        mov rax, rbx
        shr rax, 2
        mov rcx, 3
        mul rcx
        cvtsi2ss xmm0, rax
        cvtsi2ss xmm1, rax
        call glVertex2f
        mov rax, rbx
        cvtsi2ss xmm0, rax
        xorps xmm1, xmm1
        call glVertex2f
        mov rax, rbx
        shr rax, 2
        mov rcx, 3
        mul rcx
        cvtsi2ss xmm0, rax
        neg rax
        cvtsi2ss xmm1, rax
        call glVertex2f
        xorps xmm0, xmm0
        mov rax, rbx
        cvtsi2ss xmm1, rax
        mov eax, FLOAT_SIGN_MASK
        movd xmm2, eax
        xorps xmm1, xmm2
        call glVertex2f
        mov rax, rbx
        shr rax, 2
        mov rcx, 3
        mul rcx
        neg rax
        cvtsi2ss xmm0, rax
        cvtsi2ss xmm1, rax
        call glVertex2f
        mov rax, rbx
        cvtsi2ss xmm0, rax
        mov eax, FLOAT_SIGN_MASK
        movd xmm1, eax
        xorps xmm0, xmm1
        xorps xmm1, xmm1
        call glVertex2f
        mov rax, rbx
        shr rax, 2
        mov rcx, 3
        mul rcx
        cvtsi2ss xmm1, rax
        neg rax
        cvtsi2ss xmm0, rax
        call glVertex2f
        pop rbx
        add rsp, 28h
        call glEnd
        add rsp, 28h
        pop rcx
asteroidsForContinue:
        inc rcx
        jmp asteroidsFor
asteroidsForEnd:

        call PrintScore

        mov rcx, hDC
        call SwapBuffers
        add rsp, 28h
        xor rax, rax
        ret
Draw endp

;================================================
;   PrintScore
;================================================
PrintScore proc
        sub rsp, 28h

        call glLoadIdentity

        ; Makes it print the score in the top center of the screen
        mov eax, WINDOW_WIDTH
        shr eax, 1
        cvtsi2ss xmm0, eax
        mov eax, WINDOW_HEIGHT
        mov ecx, 6
        xor rdx, rdx
        div ecx
        mov ecx, WINDOW_HEIGHT
        sub ecx, eax
        cvtsi2ss xmm1, ecx
        xorps xmm2, xmm2
        call glTranslatef

        ; Prints score
        xor rcx, rcx
        mov ecx, SCORE
scoreFor:
        push rcx
        ; Gets the least significant digit
        mov eax, ecx
        mov ecx, 10
        xor rdx, rdx
        div ecx
        ; Prints it
        mov rax, sizeof(NUMDISPLAY)
        mov rcx, rdx
        mul ecx
        lea rcx, numDisplayes
        lea rcx, NUMDISPLAY ptr[rcx + rax]
        sub rsp, 18h
        call PrintDigit
        add rsp, 18h
        pop rcx
        ; Ends the loop if the number is less than 10
        cmp ecx, 10
        jl scoreForEnd
        ; Moves the coordinate system to the left to accommodate the next digit
        push rcx
        sub rsp, 18h
        mov eax, NUMERAL_WIDTH
        add eax, NUMERAL_WIDTH
        add eax, 10
        neg eax
        cvtsi2ss xmm0, eax
        xorps xmm1, xmm1
        xorps xmm2, xmm2
        call glTranslatef
        add rsp, 18h
        pop rcx
        ; Divides the number by 10
        mov eax, ecx
        mov ecx, 10
        xor rdx, rdx
        div ecx
        mov ecx, eax
        jmp scoreFor
scoreForEnd:

        call glLoadIdentity

        add rsp, 28h
        ret
PrintScore endp

;================================================
;   PrintDigit
;
;   rcx = NUMDISPLAY - An address of NUMDISPLAY structure
;================================================
PrintDigit proc
        push rbp
        lea rbp, [rsp + 8h]
        mov [rbp + 8h], rcx
        sub rsp, 30h

        ; Top
        mov rdx, [rbp + 8h]
        mov al, (NUMDISPLAY ptr [rdx]).top
        test al, al
        je @f
        mov rcx, GL_LINE_STRIP
        call glBegin
        movd xmm0, [TEXT_COLOR_R]
        movd xmm1, [TEXT_COLOR_G]
        movd xmm2, [TEXT_COLOR_B]
        call glColor3f
        mov eax, NUMERAL_WIDTH
        neg rax
        cvtsi2ss xmm0, eax
        mov eax, NUMERAL_HEIGHT
        cvtsi2ss xmm1, eax
        call glVertex2f
        mov eax, NUMERAL_WIDTH
        cvtsi2ss xmm0, eax
        mov eax, NUMERAL_HEIGHT
        cvtsi2ss xmm1, eax
        call glVertex2f
        call glEnd
@@:

        ; Center
        mov rdx, [rbp + 8h]
        mov al, (NUMDISPLAY ptr [rdx]).center
        test al, al
        je @f
        mov rcx, GL_LINE_STRIP
        call glBegin
        movd xmm0, [TEXT_COLOR_R]
        movd xmm1, [TEXT_COLOR_G]
        movd xmm2, [TEXT_COLOR_B]
        call glColor3f
        mov eax, NUMERAL_WIDTH
        neg rax
        cvtsi2ss xmm0, eax
        xorps xmm1, xmm1
        call glVertex2f
        mov eax, NUMERAL_WIDTH
        cvtsi2ss xmm0, eax
        xorps xmm1, xmm1
        call glVertex2f
        call glEnd
@@:

        ; Bottom
        mov rdx, [rbp + 8h]
        mov al, (NUMDISPLAY ptr [rdx]).bottom
        test al, al
        je @f
        mov rcx, GL_LINE_STRIP
        call glBegin
        movd xmm0, [TEXT_COLOR_R]
        movd xmm1, [TEXT_COLOR_G]
        movd xmm2, [TEXT_COLOR_B]
        call glColor3f
        mov eax, NUMERAL_WIDTH
        neg rax
        cvtsi2ss xmm0, eax
        mov eax, NUMERAL_HEIGHT
        neg rax
        cvtsi2ss xmm1, eax
        call glVertex2f
        mov eax, NUMERAL_WIDTH
        cvtsi2ss xmm0, eax
        mov eax, NUMERAL_HEIGHT
        neg rax
        cvtsi2ss xmm1, eax
        call glVertex2f
        call glEnd
@@:

        ; Top left
        mov rdx, [rbp + 8h]
        mov al, (NUMDISPLAY ptr [rdx]).topLeft
        test al, al
        je @f
        mov rcx, GL_LINE_STRIP
        call glBegin
        movd xmm0, [TEXT_COLOR_R]
        movd xmm1, [TEXT_COLOR_G]
        movd xmm2, [TEXT_COLOR_B]
        call glColor3f
        mov eax, NUMERAL_WIDTH
        neg rax
        cvtsi2ss xmm0, eax
        mov eax, NUMERAL_HEIGHT
        cvtsi2ss xmm1, eax
        call glVertex2f
        mov eax, NUMERAL_WIDTH
        neg rax
        cvtsi2ss xmm0, eax
        xorps xmm1, xmm1
        call glVertex2f
        call glEnd
@@:

        ; Top right
        mov rdx, [rbp + 8h]
        mov al, (NUMDISPLAY ptr [rdx]).topRight
        test al, al
        je @f
        mov rcx, GL_LINE_STRIP
        call glBegin
        movd xmm0, [TEXT_COLOR_R]
        movd xmm1, [TEXT_COLOR_G]
        movd xmm2, [TEXT_COLOR_B]
        call glColor3f
        mov eax, NUMERAL_WIDTH
        cvtsi2ss xmm0, eax
        mov eax, NUMERAL_HEIGHT
        cvtsi2ss xmm1, eax
        call glVertex2f
        mov eax, NUMERAL_WIDTH
        cvtsi2ss xmm0, eax
        xorps xmm1, xmm1
        call glVertex2f
        call glEnd
@@:

        ; Bottom left
        mov rdx, [rbp + 8h]
        mov al, (NUMDISPLAY ptr [rdx]).bottomLeft
        test al, al
        je @f
        mov rcx, GL_LINE_STRIP
        call glBegin
        movd xmm0, [TEXT_COLOR_R]
        movd xmm1, [TEXT_COLOR_G]
        movd xmm2, [TEXT_COLOR_B]
        call glColor3f
        mov eax, NUMERAL_WIDTH
        neg rax
        cvtsi2ss xmm0, eax
        xorps xmm1, xmm1
        call glVertex2f
        mov eax, NUMERAL_WIDTH
        neg rax
        cvtsi2ss xmm0, eax
        mov eax, NUMERAL_HEIGHT
        neg rax
        cvtsi2ss xmm1, eax
        call glVertex2f
        call glEnd
@@:

        ; Bottom right
        mov rdx, [rbp + 8h]
        mov al, (NUMDISPLAY ptr [rdx]).bottomRight
        test al, al
        je @f
        mov rcx, GL_LINE_STRIP
        call glBegin
        movd xmm0, [TEXT_COLOR_R]
        movd xmm1, [TEXT_COLOR_G]
        movd xmm2, [TEXT_COLOR_B]
        call glColor3f
        mov eax, NUMERAL_WIDTH
        cvtsi2ss xmm0, eax
        xorps xmm1, xmm1
        call glVertex2f
        mov eax, NUMERAL_WIDTH
        cvtsi2ss xmm0, eax
        mov eax, NUMERAL_HEIGHT
        neg rax
        cvtsi2ss xmm1, eax
        call glVertex2f
        call glEnd
@@:

        add rsp, 30h
        pop rbp
        ret
PrintDigit endp

;================================================
;   RestartGame
;================================================
RestartGame proc
        local pos:POINTF
        sub rsp, 20h
        
        ; Resets score/ship if the ship is destroyed
         mov al, ship.destroyed
        test al, al
        jz @f
        mov eax, ASTEROIDS_ON_START
        mov ASTEROIDS_ON_RESTART, eax
        ; Score
        xor rax, rax
        mov SCORE, eax
        ; Ship
        lea rcx, ship
        xor rdx, rdx
        mov r8, sizeof ship
        call memset
        ; Places the ship in the center of the screen
        mov eax, WINDOW_WIDTH
        shr eax, 1
        cvtsi2ss xmm0, eax
        movss ship.pos.x, xmm0
        mov eax, WINDOW_HEIGHT
        shr eax, 1
        cvtsi2ss xmm0, eax
        movss ship.pos.y, xmm0
        @@:

        ; Resets everything else
        lea rcx, bullets
        xor rdx, rdx
        mov r8, sizeof bullets
        call memset
        lea rcx, asteroids
        xor rdx, rdx
        mov r8, sizeof asteroids
        call memset
        lea rcx, effects
        xor rdx, rdx
        mov r8, sizeof effects
        call memset
 
        ; Places asteroids randomly on the screen
        xor rcx, rcx
asteroidsFor:
        cmp ecx, ASTEROIDS_ON_RESTART
        jge asteroidsForEnd
        ; Generates the x-coordinate position
        push rcx
        xor rcx, rcx
        mov edx, WINDOW_WIDTH
        sub rsp, 28h
        call Rand
        add rsp, 28h
        pop rcx
        cvtsi2ss xmm0, eax
        movss pos.x, xmm0
        ; Generates the y-coordinate position
        push rcx
        xor rcx, rcx
        mov edx, WINDOW_HEIGHT
        sub rsp, 28h
        call Rand
        add rsp, 28h
        pop rcx
        cvtsi2ss xmm0, eax
        movss pos.y, xmm0
        push rcx
        lea rcx, pos
        mov rdx, ASTEROID_BIG
        sub rsp, 28h
        call SpawnAsteroid
        add rsp, 28h
        pop rcx
        inc rcx
        jmp asteroidsFor
asteroidsForEnd:

        add rsp, 20h
        ret
RestartGame endp

;================================================
;   Rand
;
;   ecx = min - A minimal number for a random number
;   edx = max - A maximal number for a random number
;
;   Returns a random number from min to max in eax
;================================================
Rand proc
        push rbp
        lea rbp, [rsp + 8h]
        mov [rbp + 8h], ecx
        mov [rbp + 10h], edx
        sub rsp, 20h        
        mov eax, randSeed

        ; Initializes random seed if it's zero
        test rax, rax
        jnz @f
        xor rcx, rcx
        call time
        mov rcx, rax
        call srand
        call rand
        mov randSeed, eax
@@:
    
        ; Calculates the divider
        push r12
        mov r12d, [rbp + 10h]
        mov ecx, [rbp + 8h]
        sub r12d, ecx
        add r12d, 1

        ; Generates a random number from min to max
        mov ecx, 343FDh
        mul ecx
        mov ecx, 269EC3h
        add eax, ecx
        mov randSeed, eax
        mov ecx, eax
        shr ecx, 15
        xor eax, ecx
        xor rdx, rdx
        div r12d
        xor r12d, r12d
        mov eax, edx
        mov ecx, [rbp + 8h]
        add eax, ecx
        pop r12

        add rsp, 20h
        pop rbp
        ret
Rand endp

;================================================
;   InitWindow
;
;   Returns 0 if it succeeds, otherwise returns 1
;================================================
InitWindow proc
        sub rsp, 28h
        mov ecx, WINDOW_WIDTH
        mov windowRect.right, ecx
        mov ecx, WINDOW_HEIGHT
        mov windowRect.bottom, ecx

        ; Gets an instance
        xor rcx, rcx
        call GetModuleHandleA
        mov hInstance, rax

        ; Registers class
        mov wc.style, CS_HREDRAW or CS_VREDRAW or CS_OWNDC
        lea rax, [WndProc]
        mov wc.lpfnWndProc, rax
        mov rax, hInstance
        mov wc.hInstance, rax
        lea rcx, hInstance
        mov rdx, IDI_APPLICATION
        call LoadIconA
        mov wc.hIcon, rax
        xor rcx, rcx
        mov rdx, IDC_ARROW
        call LoadCursorA
        mov wc.hCursor, rax
        lea rax, [className]
        mov wc.lpszClassName, rax
        lea rcx, wc
        call RegisterClassA
        test rax, rax
        jnz @f
        lea rcx, registerClassError
        call ErrorDialog
        mov rax, 1
        jmp exit
@@:

        ; Screen resolution switching
        mov al, FULLSCREEN
        test al, al
        jz @f
        lea rcx, devMode
        xor rdx, rdx
        mov r8, sizeof DEVMODEA
        call memset
        mov devMode.dmSize, sizeof DEVMODEA
        mov eax, WINDOW_WIDTH
        mov devMode.dmPelsWidth, eax
        mov eax, WINDOW_HEIGHT
        mov devMode.dmPelsHeight, eax
        mov devMode.dmBitsPerPel, 32
        mov devMode.dmFields, DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL
        lea rcx, devMode
        mov rdx, CDS_FULLSCREEN
        call ChangeDisplaySettingsA
@@:

        ; Adjusts a window to true requested size
        mov al, FULLSCREEN
        test al, al
        mov rdx, dwFullscreenStyle
        mov r9, dwExFullscreenStyle
        jnz @f
        mov rdx, dwStyle
        mov r9, dwExStyle
@@:     lea rcx, windowRect
        mov r8, 1
        call AdjustWindowRectEx

        ; Creates a window
        push 0
        push hInstance
        push 0
        push 0
        mov eax, windowRect.bottom
        sub eax, windowRect.top
        push rax
        mov eax, windowRect.right
        sub eax, windowRect.left
        push rax
        mov rcx, SM_CYSCREEN
        sub rsp, 30h
        call GetSystemMetrics
        add rsp, 30h
        sub eax, WINDOW_HEIGHT
        mov rcx, 2
        xor rdx, rdx
        div rcx
        push rax
        mov rcx, SM_CXSCREEN
        sub rsp, 28h
        call GetSystemMetrics
        add rsp, 28h
        sub eax, WINDOW_WIDTH
        mov rcx, 2
        xor rdx, rdx
        div rcx
        push rax
        mov al, FULLSCREEN
        test al, al
        mov r9, WS_CLIPSIBLINGS or WS_CLIPCHILDREN or dwFullscreenStyle
        jnz @f
        mov r9, WS_CLIPSIBLINGS or WS_CLIPCHILDREN or dwStyle
@@:     lea r8, [windowTitle]
        lea rdx, [className]
        mov rcx, dwExStyle
        sub rsp, 20h
        call CreateWindowExA
        add rsp, 60h
        mov hWnd, rax
        test rax, rax
        jnz @f
        lea rcx, createWindowError
        call ErrorDialog
        mov rax, 1
        jmp exit
@@:

        ; Gets the device context
        mov rcx, hWnd
        call GetDC
        mov hDC, rax
        test rax, rax
        jnz @f
        lea rcx, getDCError
        call ErrorDialog
        mov rax, 1
        jmp exit
@@:

        ; Chooses the pixel format
        mov pfd.nSize, sizeof PIXELFORMATDESCRIPTOR
        mov pfd.nVersion, 1
        mov pfd.dwFlags, PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER
        mov pfd.iPixelType, PFD_TYPE_RGBA
        mov pfd.cColorBits, 32
        mov pfd.cDepthBits, 24
        mov pfd.iLayerType, PFD_MAIN_PLANE
        mov rcx, hDC
        lea rdx, pfd
        call ChoosePixelFormat
        mov pixelFormat, eax
        test rax, rax
        jnz @f
        lea rcx, choosePFDError
        call ErrorDialog
        mov rax, 1
        jmp exit
@@:

        ; Sets the pixel format context
        mov rcx, hDC
        mov edx, pixelFormat
        lea r8, pfd
        call SetPixelFormat
        test rax, rax
        jnz @f
        lea rcx, setPFDError
        call ErrorDialog
        mov rax, 1
        jmp exit
@@:

        ; Creates a rendering context
        mov rcx, hDC
        call wglCreateContext
        mov hRC, rax
        test rax, rax
        jnz @f
        lea rcx, getDCError
        call ErrorDialog
        mov rax, 1
        jmp exit
@@:

        ; Makes the current calling rendering context
        mov rcx, hDC
        mov rdx, hRC
        call wglMakeCurrent
        test rax, rax
        jnz @f
        lea rcx, makeCurrentRCError
        call ErrorDialog
        mov rax, 1
        jmp exit
@@:

        ; Initializes renderer
        mov rcx, GL_PROJECTION
        call glMatrixMode
        call glPushMatrix
        call glLoadIdentity
        push qword ptr [GL_FAR]
        push qword ptr [GL_NEAR]
        mov eax, WINDOW_HEIGHT
        cvtsi2sd xmm3, eax
        xorps xmm2, xmm2
        mov eax, WINDOW_WIDTH
        cvtsi2sd xmm1, eax
        xorps xmm0, xmm0
        sub rsp, 20h
        call glOrtho
        add rsp, 10h
        add rsp, 20h
        mov rcx, GL_MODELVIEW
        call glMatrixMode
        call glPushMatrix
        call glLoadIdentity
        xor rax, rax

exit:   add rsp, 28h
        ret
InitWindow endp

;================================================
;   KillWindow
;================================================
KillWindow proc
        sub rsp, 28h

        ; Sets screen resolution back to the original
        mov al, FULLSCREEN
        test al, al
        jz @f
        xor rcx, rcx
        xor rdx, rdx
        call ChangeDisplaySettingsA
@@:

        ; Checks for a rendering context
        lea rax, hRC
        test rax, rax
        jz noRCFound

        ; Resets the current calling rendering context
        xor rcx, rcx
        xor rdx, rdx
        call wglMakeCurrent
        test rax, rax
        jnz @f
        lea rcx, resetCurrentRCError
        call ErrorDialog
@@:

        ; Deletes the rendering context
        mov rcx, hRC
        call wglDeleteContext
        test rax, rax
        jnz @f
        lea rcx, deleteRCError
        call ErrorDialog
@@:
noRCFound:

        ; Releases the device context
        lea rax, hDC
        test rax, rax
        jz @f
        mov rcx, hWnd
        mov rdx, hDC
        call ReleaseDC
        test rax, rax
        jnz @f
        lea rcx, releaseDCError
        call ErrorDialog
@@:

        ; Destroys the window
        lea rax, hWnd
        test rax, rax
        jz @f
        mov rcx, hWnd
        call DestroyWindow
        test rax, rax
        jnz @f
        lea rcx, destroyWindowError
        call ErrorDialog
@@:

        ; Unregisters class
        lea rcx, className
        mov rdx, hInstance
        call UnregisterClassA
        test rax, rax
        jnz @f
        lea rcx, unregisterClassError
        call ErrorDialog
@@:

        add rsp, 28h
        xor rax, rax
        ret
KillWindow endp

;================================================
;   ErrorDialog
;
;   rcx = message - base address of string array
;================================================
ErrorDialog proc
        sub rsp, 28h
        mov rdx, rcx
        xor rcx, rcx
        lea r8, errorTitle
        xor r9, r9
        call MessageBoxA
        add rsp, 28h
        ret
ErrorDialog endp

;================================================
;   WndProc
;
;   rcx = HWND - An address of a handle to the window
;   rdx = UINT - The message
;   r8 = WPARAM - Additional message information
;   r9 = LPARAM - Additional message information
;================================================
WndProc proc
        push rbp
        lea rbp, [rsp + 8h]
        mov [rbp + 8h], rcx
        mov [rbp + 10h], rdx
        mov [rbp + 18h], r8
        mov [rbp + 20h], r9
        sub rsp, 20h
        
        cmp rdx, WM_CLOSE
        jne @f
        xor rcx, rcx
        call PostQuitMessage
        add rsp, 20h
        pop rbp
        mov rax, 1
        ret
@@:

        cmp rdx, WM_PAINT
        jne @f
        call Draw
        mov rcx, hWnd
        xor rdx, rdx
        call ValidateRect
        jmp exit
@@:

        cmp rdx, WM_KEYDOWN
        jne notKeyDown
        lea r12, keys
        mov al, byte ptr [r12 + r8]
        test al, al
        jnz @f
        lea rax, keysPressed
        mov byte ptr [rax + r8], 1
@@:     mov byte ptr [r12 + r8], 1
        xor r12, r12
        jmp exit
notKeyDown:

        cmp rdx, WM_KEYUP
        jne @f
        lea rax, keys
        mov byte ptr [rax + r8], 0
        jmp exit
@@:

exit:   mov rcx, [rbp + 8h] 
        mov rdx, [rbp + 10h]
        mov r8, [rbp + 18h] 
        mov r9, [rbp + 20h] 
        call DefWindowProcA
        add rsp, 20h
        pop rbp
        ret
WndProc endp
end

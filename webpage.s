global _start

section .data
sock_in:
dw 2 ; use ipv4
dw 0x981F ; port 8088 in big endian
dd 0; accepts on all interfaces 0.0.0.0
times 8 db 0 ; padding, fill the rest with 0s.

filename db "index.html",0 ; use index.html and load it

file_len equ 740 ; size of index.html, compute with wc -c < index.html.
headers db "HTTP/1.1 200 OK",13,10 ; use 13 for return, 10 for newline. http needs it
db "Content-Length: 740",13,10; same idea, setting length of html. same computer. kinda annoying ik but its way easier than me making this dynamic
db "Content-Type: text/html",13,10; just a simple test page
db 13,10 ; need seperation between headers and data
headers_len equ $-headers ; dynamically find msg length, i dont really need this since i use the same headers but still nice to have

section .text
_start:
call startserver
call serve

startserver:
call createsocket
call bindsocket
call listen
ret

serve:
call accept
call newthread
jmp serve

createsocket:
mov rax,41 ; socket syscall code
mov rdi,2 ; 2 means ipv4
mov rsi,1  ;1 for sockstream
mov rdx,6 ; 6 for tcp
syscall
mov r12, rax ;  saving file descriptor in r12, when syscall is called it returns in rax
ret

bindsocket:
mov rax,49 ; code for bind syscall
mov rdi,r12 ; using return socket file descriptor
lea rsi,[rel sock_in] ;requires a struct, this loads the sock_in struct
mov rdx,16 ; size of struct
syscall
ret

listen:
mov rax,50 ; code for listen
mov rdi,r12 ; using fd we saved in create
mov rsi,10 ; accepts 10 new pending connections before rejection
syscall
ret

accept:
mov rax,43 ; code for accept
mov rdi, r12; using fd
xor rsi,rsi ; zeroing out second and third args, since we dont care ab client address or port
xor rdx,rdx ; i love when syscalls are nullable :)
syscall
mov r13, rax; saving new fd
ret

newthread:
call mmap
call clone
ret

mmap:	
mov rax,9 ;syscal for memory map
xor rdi,rdi; clear out first arg
mov rsi, 8 ; eight bit stack for each thread (enough for return address)
mov rdx,3; rw perms
mov r10,0x22;maps thread with map private+map anonymous. map private = 0x02, map anon is 0x20. private means mem is not connected to thread. anon means mem is not connected to file and will be all 0s.
mov r8,-1 ; mapping a file directly into memory, need fd to be -1
xor r9,r9   ; ignored argument normally for offset, set to 0.
syscall
mov rbx,rax ;save base to free later in child
ret

clone:
mov rax, 56 ;syscal code for clone
xor rdi,rdi ; this normally defines what signal the parent gets back. 0x11 is a normal thing to do. I don't care about my child and i will kill them anyways
lea rsi,[rbx+8] ;load base plus eight bits
xor rdx,rdx ; zeroing out args for features i don't know how to use or what they do tbh
xor r10,r10 ; but i used this in mmap so i have to zero it out here
xor r8,r8 ; so manny nullable args :) lots of clearing tho
syscall
cmp rax,0 ; is the return value 0?
je childwork ; if it is, jump to child work because you are a child
ret ; if not, return and wait for new connection

childwork:
call write
call openindex
call serveindex
call close
call freechild

freechild:
mov rax,11 ;munmap, this call releases memory
mov rdi,rbx; load base address in we saved earlier
mov rsi,8 ; the eight bits we will use
syscall

mov rax,60; exitsyscall
mov rdi,0; puts 0 in to exit
syscall

openindex:
mov rax,2 ; syscall for open
lea rdi, [rel filename] ; this references index.html
mov rsi, 0 ; read perms
syscall
mov r14, rax ; save the fd in r14
ret

serveindex:
mov rax, 40 ; syscall sendfile
mov rdi, r13; use the fd we write from
mov rsi,r14 ; read from the index.html that we opened in openindex
xor rdx, rdx ; no offset, null it out
mov r10, file_len ; count of bytes to send
syscall
ret

write:
mov rax,1; write code
mov rdi,r13 ; load new fd
lea rsi,[rel headers] ; load struct of what we serve
mov rdx, headers_len ; put length in the 3d arg
syscall
ret

close:
mov rax,3   ; close syscall
mov rdi,r13 ; closeing fd for write
syscall
mov rax,3
mov rdi,r14 ; closing fd for serving
syscall
ret

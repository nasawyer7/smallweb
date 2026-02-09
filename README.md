# smallweb
A multi-threaded linux webserver written in assembly that uses 8 bytes of memory per client. Written without ai.

# Deployment

Runs on port 8088. Works with an index.html of size 740. Update headers with the size of index.html if any edits are made. 
Compile quickly with:
```
./assembler.sh helloWorld.s
```
Add -g to previous command to debug with gdb.

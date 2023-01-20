answer=1;
arduino=serial('com3','BaudRate',9600);
fopen(arduino);
while answer
fprintf(arduino,'%s',char(answer));
answer=input('123');
end
fclose(arduino);
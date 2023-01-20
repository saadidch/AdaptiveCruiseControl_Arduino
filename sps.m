clc;
clear all;
a = arduino('com5','uno','libraries',{'servo','ExampleLCD/LCDAddon'});
s=servo(a,'D9','MinPulseDuration',700*10^-6,'Maxpulseduration',2300*10^-6); % Giving Servo motor connection 
lcd=addon(a,'ExampleLCD/LCDAddon','RegisterSelectPin','D7','EnablePin','D6','DataPins',{'D5','D4','D3','D2'});
NumberOfCars=0;  %Initially no car is there and parking is empty
availablespace=13; %We have total 13 available space for parking 


%Now let’s give connection to lcd libraries and connection 

initializeLCD(lcd,'Rows', 2, 'Columns', 16);  % initializing LCD 


%%Defining Push buttons for entry and exit
configurePin(a,'A1','DigitalInput')
configurePin(a,'A4','DigitalInput') 
%%Defining LED lights
writeDigitalPin(a,'D13',1); 
writeDigitalPin(a,'D12',0);
writePosition(s,0); 

% at first lcd is clear 

printLCD(lcd,'SMART PARKING');
pause(2);
% % % clearLCD(lcd); 
% % % printLCD(lcd,'Team Number 19');
% % % pause(2);
% % % clearLCD(lcd); 
% % % printLCD(lcd,'Faaiz-110061475');
% % % pause(2);
% % % clearLCD(lcd);
% % % printLCD(lcd,'Arvind-110061475');
% % % pause(2);
% % % clearLCD(lcd);
% % % printLCD(lcd,'Siva-110061475');
% % % pause(2);
% % % clearLCD(lcd);
printLCD(lcd,'Welcome!');
pause(2);
clearLCD(lcd);
printLCD(lcd,['Empty slots:',num2str(availablespace)]) 
%using while condition to manipulate number of parking slots, red and green
%light and servo motor

while 1  % This will run in loop till the condition is true
    enter_push=readDigitalPin(a,'A1');
    exit_push=readDigitalPin(a,'A4');
    if availablespace>0
        if enter_push==true 
            clearLCD(lcd);
            printLCD(lcd,'Welcome!')
            availablespace=availablespace-1;
            writeDigitalPin(a,'D12',1);
            writeDigitalPin(a,'D13',0);
            writePosition(s,0.5)
            pause(2) 
            writePosition(s,0)
            str1='Empty slots = '; 
            str2=num2str(availablespace); 
            printLCD(lcd,strcat(str1,str2));
        end
        writeDigitalPin(a,'D12',0);
        writeDigitalPin(a,'D13',1);
    else
        clearLCD(lcd); 
        printLCD(lcd,'PLZ Come Later'); 
    end
    if availablespace<13
        if exit_push==true 
            writeDigitalPin(a,'D12',1); 
            writeDigitalPin(a,'D13',0); 
            clearLCD(lcd); 
            printLCD(lcd,'Have a safedrive') 
            availablespace=availablespace+1; 
            str1='Empty slots = ';
            str2=num2str(availablespace); 
            printLCD(lcd,strcat(str1,str2)); 
            writePosition(s,0.5)
            pause(2)
            writePosition(s,0)
        end
        writeDigitalPin(a,'D12',0); 
        writeDigitalPin(a,'D13',1); 
    end
end
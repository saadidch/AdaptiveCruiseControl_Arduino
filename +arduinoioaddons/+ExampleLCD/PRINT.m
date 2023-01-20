a = arduino('com3','uno','libraries','ExampleLCD/LCDAddon');
lcd = addon(a,'ExampleLCD/LCDAddon','RegisterSelectPin','D7','EnablePin','D6','DataPins',{'D5','D4','D3','D2'});
initializeLCD(lcd);
printLCD(lcd,'faaiz');
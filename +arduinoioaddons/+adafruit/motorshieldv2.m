classdef motorshieldv2 < matlabshared.addon.LibraryBase & matlab.mixin.CustomDisplay 
% MOTORSHIELDV2 Create an Adafruit motor shield v2 device object.

% Copyright 2014-2019 The MathWorks, Inc.

    properties(Access = private, Constant = true)
        CREATE_MOTOR_SHIELD = hex2dec('00')
        DELETE_MOTOR_SHIELD = hex2dec('01')
    end
    properties(GetAccess = public, SetAccess = protected)
        SCLPin
        SDAPin
    end
    properties(SetAccess = immutable)
        I2CAddress
        PWMFrequency
    end
    properties(Access = private)
        Bus
        CountCutOff
        ShieldSlotNum
    end
    
    properties(Access = private)
        ResourceOwner = 'AdafruitMotorShieldV2';
        MinI2CAddress = hex2dec('60');  
        MaxI2CAddress = hex2dec('7F');   
    end
    
    properties(Access = protected, Constant = true)
        LibraryName = 'Adafruit/MotorShieldV2'
        DependentLibraries = {'Servo', 'I2C'}
        LibraryHeaderFiles = 'Adafruit_MotorShield/Adafruit_MotorShield.h'
        CppHeaderFile = fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', 'MotorShieldV2Base.h')
        CppClassName = 'MotorShieldV2Base'
    end
    
    %% Constructor
    methods(Hidden, Access = public)
        function obj = motorshieldv2(parentObj, varargin)
            narginchk(1,5);
            obj.Parent = parentObj;
            
            if ismember(obj.Parent.Board, {'Uno', 'Leonardo'})
                obj.CountCutOff = 4;
            else
                obj.CountCutOff = 32;
            end
            count = incrementResourceCount(obj.Parent, obj.ResourceOwner);
            % increment I2C resource count as well to keep track on number
            % of devices on I2C bus and unconfigure pins no devices during
            % destruction
            incrementResourceCount(obj.Parent,'I2C');
            if count > obj.CountCutOff
                obj.localizedError('MATLAB:arduinoio:general:maxAddonLimit',...
                    num2str(obj.CountCutOff),...
                    obj.ResourceOwner,...
                    obj.Parent.Board);
            end  
            try
                p = inputParser;
                addParameter(p, 'I2CAddress', hex2dec('60'));
                addParameter(p, 'PWMFrequency', 1600);
                parse(p, varargin{:});
            catch e
                message = e.message;
                index = strfind(message, '''');
                str = message(index(1)+1:index(2)-1);
                switch e.identifier
                     case 'MATLAB:InputParser:ParamMissingValue'
                         % throw valid error if user doesn't provide a
                         % value for parameter
                        try
                           validatestring(str,p.Parameters);
                        catch
                            obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                            obj.ResourceOwner, ...
                            matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
                        end
                        obj.localizedError('MATLAB:InputParser:ParamMissingValue', str);
                    case 'MATLAB:InputParser:UnmatchedParameter'
                        % throw a valid error if user tries to use invalid
                        % NV pair
                        obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                        obj.ResourceOwner, ...
                        matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
                    otherwise
                        %do nothing, as error is coming from an unknown
                        %scenario
                end
            end
            
            address = validateAddress(obj, p.Results.I2CAddress);
            try
                i2cAddresses = getSharedResourceProperty(parentObj, obj.ResourceOwner, 'i2cAddresses');
            catch
                i2cAddresses = [];
            end
            if ismember(address, i2cAddresses)
                obj.localizedError('MATLAB:arduinoio:general:conflictI2CAddress', ...
                    num2str(address),...
                    dec2hex(address));
            end
            i2cAddresses = [i2cAddresses address];
            setSharedResourceProperty(parentObj, obj.ResourceOwner, 'i2cAddresses', i2cAddresses);
            obj.I2CAddress = address;
            
            frequency = matlabshared.hwsdk.internal.validateDoubleParameterRanged('PWM frequency', p.Results.PWMFrequency, 0, 2^15-1, 'Hz');
            obj.PWMFrequency = frequency;
            
                      
            configureI2C(obj);
            
            obj.ShieldSlotNum = getFreeResourceSlot(obj.Parent, obj.ResourceOwner);
            createMotorShield(obj);
            
            setSharedResourceProperty(parentObj, 'I2C', 'I2CIsUsed', true);
        end
    end
    
    %% Destructor
    methods (Access=protected)
        function delete(obj)
            originalState = warning('off','MATLAB:class:DestructorError');
            try
                parentObj = obj.Parent;
                decrementResourceCount(obj.Parent, obj.ResourceOwner);
                countI2C = decrementResourceCount(obj.Parent, 'I2C');
                i2cAddresses = getSharedResourceProperty(parentObj, obj.ResourceOwner, 'i2cAddresses');
                if ~isempty(i2cAddresses)
                    if ~isempty(obj.I2CAddress) 
                        % Can be empty if failed during construction
                        i2cAddresses(i2cAddresses==obj.I2CAddress) = [];
                    end
                end
                setSharedResourceProperty(parentObj, obj.ResourceOwner, 'i2cAddresses', i2cAddresses);
                if ~isempty(obj.ShieldSlotNum) 
                    % if construction fails for duplicate I2CAddress captured in g1939189 this will be empty
                    % the ResourceSlot shouldn't be cleared
                    clearResourceSlot(parentObj, obj.ResourceOwner, obj.ShieldSlotNum);
                    deleteMotorShield(obj);
                    if(countI2C == 0)
                        %unconfigure I2C Pins
                        I2CTerminals = parentObj.getI2CTerminals();
                        sda = parentObj.getPinsFromTerminals(I2CTerminals(obj.Bus*2+1));
                        sda = sda{1};
                        scl = parentObj.getPinsFromTerminals(I2CTerminals(obj.Bus*2+2));
                        scl = scl{1};
                        configurePinResource(parentObj, sda, 'I2C', 'Unset', false);
                        configurePinResource(parentObj, scl, 'I2C', 'Unset', false);
                    end
                end
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
            warning(originalState.state, 'MATLAB:class:DestructorError');
        end
    end
    
    %% Public methods
    methods (Access = public)
        function servoObj = servo(obj, motornum, varargin)
            %   Attach a servo motor to the specified port on Adafruit motor shield.
            %
            %   Syntax:
            %   s = servo(dev, motornum)
            %   s = servo(dev, motornum,Name,Value)
            %
            %   Description:
            %   s = servo(dev, motornum)            Creates a servo motor object connected to the specified port on the Adafruit motor shield.
            %   s = servo(dev, motornum,Name,Value) Creates a servo motor object with additional options specified by one or more Name-Value pair arguments.
            %
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       shield = addon(a, 'Adafruit/MotorShieldV2');
            %       s = servo(shield,1);
            %
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       shield = addon(a, 'Adafruit/MotorShieldV2');
            %       s = servo(shield,1,'MinPulseDuration',1e-3,'MaxPulseDuration',2e-3);
            %
            %   Input Arguments:
            %   dev      - Adafruit motor shield v2 object
            %   motornum - Port number the motor is connected to on the shield (numeric)
            %
            %   Name-Value Pair Input Arguments:
            %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value. 
            %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
            %
            %   NV Pair:
            %   'MinPulseDuration' - The pulse duration for the servo at its minimum position (numeric, 
            %                       default 5.44e-4 seconds.
            %   'MaxPulseDuration' - The pulse duration for the servo at its maximum position (numeric, 
            %                       default 2.4e-3 seconds.
            %
            %   See also dcmotor, stepper
            
            try
                servoObj = arduinoioaddons.adafruit.Servo(obj, motornum, varargin{:});
            catch e
                throwAsCaller(e);
            end
        end
        
        function dcmotorObj = dcmotor(obj, motornum, varargin)
            %   Attach a DC motor to the specified port on Adafruit motor shield.
            %
            %   Syntax:
            %   dcm = dcmotor(dev, motornum)
            %   dcm = dcmotor(dev, motornum,Name,Value)
            %
            %   Description:
            %   dcm = dcmotor(dev, motornum)            Creates a dcmotor motor object connected to the specified port on the Adafruit motor shield.
            %   dcm = dcmotor(dev, motornum,Name,Value) Creates a dcmotor motor object with additional options specified by one or more Name-Value pair arguments.
            %
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       shield = addon(a, 'Adafruit/MotorShieldV2');
            %       dcm = dcmotor(shield,1);
            %
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       shield = addon(a, 'Adafruit/MotorShieldV2');
            %       dcm = dcmotor(shield,1,'Speed'0.2);
            %
            %   Input Arguments:
            %   dev      - Adafruit motor shield v2 object
            %   motornum - Port number the motor is connected to on the shield (numeric)
            %
            %   Name-Value Pair Input Arguments:
            %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value. 
            %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
            %
            %   NV Pair:
            %   'Speed' - The speed of the motor that ranges from -1 to 1 (numeric, 
            %                     default 0.
            %
            %   See also servo, stepper
            
            try
                dcmotorObj = arduinoioaddons.adafruit.dcmotorv2(obj, motornum, varargin{:});
            catch e
                throwAsCaller(e);
            end
        end
        
        function stepperObj = stepper(obj, motornum, varargin)
            %   Attach a stepper motor to the specified port on Adafruit motor shield.
            %
            %   Syntax:
            %   sm = stepper(dev, motornum, sprev)
            %   sm = stepper(dev, motornum, sprev, Name, Value)
            %
            %   Description:
            %   sm = stepper(dev, motornum)            Creates a stepper motor object connected to the specified port on the Adafruit motor shield.
            %   sm = stepper(dev, motornum, sprev, Name,Value) Creates a stepper motor object with additional options specified by one or more Name-Value pair arguments.
            %
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       shield = addon(a, 'Adafruit/MotorShieldV2');
            %       sm = stepper(shield,1,200);
            %
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       shield = addon(a, 'Adafruit/MotorShieldV2');
            %       sm = stepper(shield,1,200,'RPM',10);
            %
            %   Input Arguments:
            %   dev      - Adafruit motor shield v2 object
            %   motornum - Port number the motor is connected to on the shield (numeric)
            %   sprev    - steps per revolution
            %
            %   Name-Value Pair Input Arguments:
            %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value. 
            %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
            %
            %   NV Pair:
            %   'RPM'      - The speed of the motor which is revolutions per minute (numeric, default 0).
            %
            %   'StepType' - The type of coil activation for the motor that can be,   
            %                     'Single', 'Double', 'Interleave', 'Microstep'(character vector, default 'Single').
            %
            %   See also dcmotor, servo
            
            try
                stepperObj = arduinoioaddons.adafruit.stepper(obj, motornum, varargin{:});
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    %% Private methods
    methods (Access = private)
        function createMotorShield(obj)        
            commandID = obj.CREATE_MOTOR_SHIELD;
            frequency = typecast(uint16(obj.PWMFrequency), 'uint8');
            data = [uint8(obj.I2CAddress), frequency];
            sendCommandCustom(obj, obj.LibraryName, commandID, data');
        end
        
        function deleteMotorShield(obj)
            commandID = obj.DELETE_MOTOR_SHIELD;
            
            params = [];
            sendCommandCustom(obj, obj.LibraryName, commandID, params);
        end
    end
    
    %% Helper method to related classes
    methods (Access = {?arduinoioaddons.adafruit.Servo, ...
                       ?arduinoioaddons.adafruit.dcmotorv2, ...
                       ?arduinoioaddons.adafruit.stepper})
        function output = sendShieldCommand(obj, commandID, inputs, timeout)
            switch nargin
                case 3
                    output = sendCommandCustom(obj, obj.LibraryName, commandID, inputs);
                case 4
                    output = sendCommandCustom(obj, obj.LibraryName, commandID, inputs, timeout);
                otherwise
            end
        end
    end
    
    methods(Access = private)
        function addr = validateAddress(obj, address)
            if ~isempty(address)
                
                if isstring(address)
                    address = char(address);
                end
                if isempty(address)
                        obj.localizedError('MATLAB:arduinoio:general:invalidI2CAddress', '', ...
                            strcat('0x', dec2hex(obj.MinI2CAddress), '(',num2str(obj.MinI2CAddress), ')'), ...
                            strcat('0x', dec2hex(obj.MaxI2CAddress), '(',num2str(obj.MaxI2CAddress), ')'));
                end
                
                if ~ischar(address)
                    try
                        validateattributes(address, {'uint8', 'double'}, {'scalar'});
                    catch
                        obj.localizedError('MATLAB:hwsdk:general:invalidAddressType');
                    end
                    if ~(address >= 0 && ~isinf(address))
                        obj.localizedError('MATLAB:arduinoio:general:invalidI2CAddress', num2str(address), ...
                            strcat('0x', dec2hex(obj.MinI2CAddress), '(',num2str(obj.MinI2CAddress), ')'), ...
                            strcat('0x', dec2hex(obj.MaxI2CAddress), '(',num2str(obj.MaxI2CAddress), ')'));
                    end
                    try
                        addr = matlabshared.hwsdk.internal.validateIntParameterRanged('address', address, obj.MinI2CAddress, obj.MaxI2CAddress);
                    catch
                        obj.localizedError('MATLAB:arduinoio:general:invalidI2CAddress', strcat('0x', dec2hex(address), '(',num2str(address),')'), ...
                            strcat('0x', dec2hex(obj.MinI2CAddress), '(',num2str(obj.MinI2CAddress), ')'), ...
                            strcat('0x', dec2hex(obj.MaxI2CAddress), '(',num2str(obj.MaxI2CAddress), ')'));
                    end
                else
                    
                    if strcmpi(address(1:2),'0x')
                        address = address(3:end);
                    elseif strcmpi(address(end), 'h')
                        address(end) = [];
                    end
                    try
                        addr = hex2dec(address);
                    catch
                        obj.localizedError('MATLAB:arduinoio:general:invalidI2CAddress', address, ...
                            strcat('0x', dec2hex(obj.MinI2CAddress), '(',num2str(obj.MinI2CAddress), ')'), ...
                            strcat('0x', dec2hex(obj.MaxI2CAddress), '(',num2str(obj.MaxI2CAddress), ')'));
                    end
                    
                    if addr < obj.MinI2CAddress || addr > obj.MaxI2CAddress
                        obj.localizedError('MATLAB:arduinoio:general:invalidI2CAddress', ...
                            strcat('0x', dec2hex(addr),'(',num2str(addr),')'), ...
                            strcat('0x', dec2hex(obj.MinI2CAddress),'(',num2str(obj.MinI2CAddress), ')'), ...
                            strcat('0x', dec2hex(obj.MaxI2CAddress),'(',num2str(obj.MaxI2CAddress), ')'));
                    end
                end
            else
                obj.localizedError('MATLAB:arduinoio:general:invalidI2CAddress','', ...
                    strcat('0x', dec2hex(obj.MinI2CAddress),'(',num2str(obj.MinI2CAddress), ')'), ...
                    strcat('0x', dec2hex(obj.MaxI2CAddress),'(',num2str(obj.MaxI2CAddress), ')'));
            end
            
        end
    
        function configureI2C(obj)
            parentObj = obj.Parent;
            I2CTerminals = parentObj.getI2CTerminals();
            
            if ~strcmp(parentObj.Board, 'Due')
                obj.Bus =0 ;
                % ResourceOwner for I2C Pins is 'I2C' as i2c.device configures sda/scl pins with resourceOwner I2C
                % We can create another object if ResourceOwner is same,
                % else issue seen in g1995052 is seen
                resourceOwner = 'I2C'; 
                sda = parentObj.getPinsFromTerminals(I2CTerminals(obj.Bus*2+1)); 
                sda = sda{1};
                [~, ~, pinMode, pinResourceOwner] = getPinInfo(obj.Parent, sda);
                % Proceed only if the I2C pins are Unset or
                % configured to I2C
                if (strcmp(pinMode, 'I2C') || strcmp(pinMode, 'Unset')) && strcmp(pinResourceOwner, '') 
                    % Take the ownership from arduino if it is
                    % the resourceowner. If not, proceed with
                    % configuration.
                    configurePinResource(obj.Parent, sda, '', 'Unset');        
                end
                configurePinResource(parentObj, sda, resourceOwner, 'I2C', false);
                scl = parentObj.getPinsFromTerminals(I2CTerminals(obj.Bus*2+2)); 
                scl = scl{1};
                [~, ~, pinMode, pinResourceOwner] = getPinInfo(obj.Parent, scl);
                % Proceed only if the I2C pins are Unset or
                % configured to I2C
                if (strcmp(pinMode, 'I2C') || strcmp(pinMode, 'Unset')) && strcmp(pinResourceOwner, '')
                    % Take the ownership from arduino if it is
                    % the resourceowner. If not, proceed with
                    % configuration.
                    configurePinResource(obj.Parent, scl, '', 'Unset');            
                end
                configurePinResource(parentObj, scl, resourceOwner, 'I2C', false);
                obj.SCLPin = char(scl);
                obj.SDAPin = char(sda);
            else
                obj.Bus = 1;
                obj.SCLPin = 'SCL1';
                obj.SDAPin = 'SDA1';
            end
        end
    end
    
    %% Protected methods
    methods(Access = protected)
        function output = sendCommandCustom(obj, libName, commandID, inputs, timeout)
            inputs = [obj.ShieldSlotNum-1; inputs];
            if nargin > 4
                [output, ~] = sendCommand(obj, libName, commandID, inputs, timeout);
            else
                [output, ~] = sendCommand(obj, libName, commandID, inputs);
            end
        end
        
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            
            % Display main options
            fprintf('          SCLPin: ''%s''\n', obj.SCLPin);
            fprintf('          SDAPin: ''%s''\n', obj.SDAPin);
            fprintf('      I2CAddress: %-1d (''0x%02s'')\n', obj.I2CAddress, dec2hex(obj.I2CAddress));
            fprintf('    PWMFrequency: %.2d (Hz)\n', obj.PWMFrequency);
            fprintf('\n');
                  
            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end

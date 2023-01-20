classdef dcmotorv2 < arduinoio.MotorBase & matlab.mixin.CustomDisplay
    %DCMOTORV2 Create a DC motor device object.
    
    % Copyright 2018 The MathWorks, Inc.
    
    properties
        Speed = 0
    end
    
    properties (Dependent = true, Access = private)
        ConvertedSpeed
    end
    
    properties (SetAccess = private)
        IsRunning = false;
    end
    
    properties(Access = private)
        ResourceOwner = 'AdafruitMotorShieldV2\DCMotor';
    end
    
    properties(Access = private, Constant = true)
        % MATLAB defined command IDs
        CREATE_DC_MOTOR     = hex2dec('02')
        START_DC_MOTOR      = hex2dec('03')
        STOP_DC_MOTOR       = hex2dec('04')
        SET_SPEED_DC_MOTOR  = hex2dec('05')
    end
    
    properties(Access = private, Constant = true)
        ROTATE_FORWARD  = 1
        ROTATE_BACKWARD = 2
    end
    
    properties(Access = private, Constant = true)
        MaxDCMotors = 4
        ResourceMode = 'AdafruitMotorShieldV2\DCMotor';
    end
    
    %% Constructor
    methods(Hidden, Access = public)
        function obj = dcmotorv2(parentObj, motorNumber, varargin)
            obj.Pins = [];
            obj.Parent = parentObj;
            arduinoObj = parentObj.Parent;
            
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
            catch e
                throwAsCaller(e);
            end
            
            motorNumber = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                [obj.ResourceOwner 'MotorNumber'], ...
                motorNumber, ...
                1, ...
                obj.MaxDCMotors);
            
            try
                dcmotors = getSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'dcmotors');
            catch 
                locDC = 1; %#ok<NASGU>
                dcmotors = [parentObj.I2CAddress zeros(1, obj.MaxDCMotors)];
            end
            shieldDCAddresses = dcmotors(:, 1);
            [~, locDC] = ismember(parentObj.I2CAddress, shieldDCAddresses);
            if locDC == 0
                dcmotors = [dcmotors; parentObj.I2CAddress zeros(1, obj.MaxDCMotors)];
                locDC = size(dcmotors, 1);
            end
            
            % Check for resource conflict with DC Motors
            if dcmotors(locDC, motorNumber+1)
                obj.localizedError('MATLAB:arduinoio:general:conflictDCMotor', num2str(motorNumber));
            end

            % Check for resource conflict with Steppers
            steppersResource = 'AdafruitMotorShieldV2\Stepper';
            try
                steppers = getSharedResourceProperty(arduinoObj, steppersResource, 'steppers');
                shieldStepperAddresses = steppers(:, 1);
                [~, locStepper] = ismember(parentObj.I2CAddress, shieldStepperAddresses);
                if locStepper ~= 0
                    possibleConflictingStepperMotorNumber = floor((motorNumber-1)/2)+1;
                    dcMotorNumbers = [(possibleConflictingStepperMotorNumber-1)*2+1, (possibleConflictingStepperMotorNumber-1)*2+2];
                    if steppers(locStepper, possibleConflictingStepperMotorNumber+1)
                        obj.localizedError('MATLAB:arduinoio:general:conflictDCMotorTerminals', ...
                            num2str(dcMotorNumbers(1)),...
                            num2str(dcMotorNumbers(2)),...
                            num2str(possibleConflictingStepperMotorNumber));
                    end
                end
            catch e
                if ~strcmp(e.identifier, 'MATLAB:hwsdk:general:invalidResourceName')
                    throwAsCaller(e);
                end
            end

            % No clonflicts
            dcmotors(locDC, motorNumber+1) = 1;
            setSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'dcmotors', dcmotors);
            obj.MotorNumber = motorNumber;
            
            try
                p = inputParser;
                addParameter(p, 'Speed', 0);
                parse(p, varargin{:});
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                    obj.ResourceOwner, ...
                    matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
            end
            
            obj.Speed = p.Results.Speed;
            
            createDCMotor(obj);
        end
    end
    
    %%
    methods
        function start(obj)
            %   Start the DC motor.
            %
            %   Syntax:
            %   start(dev)
            %
            %   Description:
            %   Start the DC motor so that it can rotate if Speed is non-zero
            %
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       shield = addon(a, 'Adafruit/MotorShieldV2');
            %       dcm = dcmotor(shield,1,'Speed',0.3);
            %       start(dcm);
			%
            %   Input Arguments:
            %   dev       - DC motor device 
            %
			%   See also stop
            
            try
                if obj.IsRunning == false
                    if obj.Speed ~= 0
                        startDCMotor(obj);
                    end
                    obj.IsRunning = true;
                else
                    obj.localizedWarning('MATLAB:arduinoio:general:dcmotorAlreadyRunning', num2str(obj.MotorNumber));
                end
            catch e
                throwAsCaller(e);
            end
        end
        
        function stop(obj)
            %   Stop the DC motor.
            %
            %   Syntax:
            %   stop(dev)
            %
            %   Description:
            %   Stop the DC motor if it has been started
            %
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       shield = addon(a, 'Adafruit/MotorShieldV2');
            %       dcm = dcmotor(shield,1,'Speed',0.3);
            %       start(dcm);
            %       stop(dcm);
			%
            %   Input Arguments:
            %   dev       - DC motor device 
            %
			%   See also start
            
            try
                if obj.IsRunning == true
                    stopDCMotor(obj);
                    obj.IsRunning = false;
                end
            catch e
                throwAsCaller(e);
            end
        end
        
        function set.Speed(obj, speed)
            % Valid speed range is -1 to 1
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
            
                speed = matlabshared.hwsdk.internal.validateDoubleParameterRanged(...
                    'AdafruitMotorShieldV2\DCMotor Speed', speed, -1, 1);
                
                if speed == -0
                    speed = 0;
                end
                
                if obj.IsRunning == true %#ok<MCSUP>
                    convertedSpeed = round(speed*255);
                    setSpeedDCMotor(obj, convertedSpeed);
                end
                obj.Speed = speed;
            catch e
                throwAsCaller(e);
            end
        end
        
        function out = get.ConvertedSpeed(obj)
            % Convert speed from range [-1, 1] to [-255 255]
            out = round(obj.Speed * 255);
        end
    end
    
	%% Destructor
    methods (Access=protected)
        function delete(obj)
            originalState = warning('off','MATLAB:class:DestructorError');
            try
                parentObj = obj.Parent;
                arduinoObj = parentObj.Parent;
                
                % Clear the DC Motor
                dcmotors = getSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'dcmotors');
                shieldDCAddresses = dcmotors(:, 1);
                [~, locDC] = ismember(parentObj.I2CAddress, shieldDCAddresses);
                dcmotors(locDC, obj.MotorNumber+1) = 0;
                setSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'dcmotors', dcmotors);
                
                stopDCMotor(obj);
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
            warning(originalState.state, 'MATLAB:class:DestructorError');
        end
    end
    
    %% Private methods
    methods (Access = private)
        function createDCMotor(obj)
             commandID = obj.CREATE_DC_MOTOR;

             params = [];
             sendCommand(obj, commandID, params);
        end
        
        function startDCMotor(obj)
            commandID = obj.START_DC_MOTOR;
            if obj.ConvertedSpeed > 0
                direction = obj.ROTATE_FORWARD;
            else
                direction = obj.ROTATE_BACKWARD;
            end
            speed = uint8(abs(obj.ConvertedSpeed));
            params = [speed; direction];
            sendCommand(obj, commandID, params);
        end
        
        function stopDCMotor(obj)
            commandID = obj.STOP_DC_MOTOR;
            
            params = [];
            sendCommand(obj, commandID, params);
        end
        
        function setSpeedDCMotor(obj, speed)
            commandID = obj.SET_SPEED_DC_MOTOR;

            if speed > 0
                direction = 1;
            else
                direction = 2;
            end
            speed = uint8(abs(speed));
            params = [speed; direction];
            sendCommand(obj, commandID, params);
        end
    end
    
    
    %% Protected methods
    methods(Access = protected)    
        function output = sendCommand(obj, commandID, params)
            params = [obj.MotorNumber - 1; params]; 
            output = sendShieldCommand(obj.Parent, commandID, params);
        end
    end
        
    %% Protected methods
    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            
            % Display main options
            fprintf('    MotorNumber: %d (M%d)\n', obj.MotorNumber, obj.MotorNumber);
            fprintf('          Speed: %-15.2f\n', obj.Speed);
            fprintf('      IsRunning: %-15d\n', obj.IsRunning);  
            fprintf('\n');
                  
            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end
% --- Intermediate Axis Theorem (Dzhanibekov Effect) Animation ---

% Completely clearing the workspace for a fresh start.
clc;        % Clears old text in the Command Window.
clear;      % Deletes all previous variables from the Workspace.
close all;  % Closes all open figure (plot and graphic) windows.

% =========================================================================
% 1. STL FILE READING SECTION
% =========================================================================
% Importing the 3D model mesh (obtained from NX) into MATLAB.
% try-catch block: If the file is missing, it provides a clear custom 
% error message instead of crashing the program abruptly.
try
    % The 'stlread' command reads the triangular faces and vertices 
    % from the STL file and saves them into a struct named 'model'.
    model = stlread('intermediate_axis_theorem_part.stl');
catch
    % If the file is missing or incorrectly named, throw this red error and stop.
    error('STL file not found! Please check the filename and directory.');
end

% =========================================================================
% 2. PHYSICAL PARAMETERS AND INITIAL CONDITIONS
% =========================================================================
% Mass Moments of Inertia obtained from our NX analysis.
% For the theorem to work, these 3 values must be strictly distinct.
Ix = 8.394;   % Minimum moment of inertia
Iy = 10.065;  % INTERMEDIATE moment of inertia (The axis where the flip occurs)
Iz = 16.664;  % Maximum moment of inertia
I = [Ix; Iy; Iz]; % Combined into a single column vector for calculation convenience.

% Initial Angular Velocities (in rad/s)
% Vector format: [X-axis velocity; Y-axis velocity; Z-axis velocity]
% We apply a high rotational speed (5) to the intermediate axis (Y) to observe the flip.
% The 0.1 values in X and Z represent tiny spatial disturbances/imperfections.
% Without these tiny "flaws," the part would spin perfectly forever and never flip!
w0 = [0.1; 5; 0.1]; 
% Initial Orientation (Quaternion)
% The initial angular posture of the part in space, formatted as [q0; q1; q2; q3].
% If we used classic Euler angles (X-Y-Z), the system would suffer from 
% "Gimbal Lock" when axes overlap. To prevent this mathematical singularity, 
% we use 4D Quaternions. [1; 0; 0; 0] represents a "neutral/zero" rotation.
q0 = [1; 0; 0; 0]; 

% State Vector
% To solve the differential equations, we pack both the velocities (w0) 
% and the quaternion (q0) into a single 7x1 column vector.
y0 = [w0; q0];

% =========================================================================
% 3. SOLVING DIFFERENTIAL EQUATIONS (TIME INTEGRATION VIA ODE45)
% =========================================================================
% Defining the simulation duration: From 0 to 20 seconds.
tspan = [0 20]; 

% Solver precision settings (Tolerances)
% We restrict MATLAB's error margin to one-ten-millionth (1e-7) to prevent 
% energy loss or numerical drift over long simulation periods.
options = odeset('RelTol', 1e-6, 'AbsTol', 1e-6);

% The core engine solving the math: ode45
% It takes the physics rules from the 'rigidBodyDynamics' function (at the bottom),
% and solves them over 'tspan' using the 'y0' initial conditions.
% Outputs: 't' (time steps) and 'Y' (matrix containing velocities and quaternions).
[t, Y] = ode45(@(t, y) rigidBodyDynamics(t, y, I), tspan, y0, options);

% =========================================================================
% 4. VISUALIZATION AND 3D ANIMATION SETUP
% =========================================================================
% Opens an 800x600 window with a white background to display the 3D part.
fig = figure('Name', 'Simulation', 'Color', 'w', 'Position', [50 50 800 800]);

% The 'patch' command draws the 3D surface using the vertices from the STL file.
p = patch('Faces', model.ConnectivityList, 'Vertices', model.Points);
p.FaceColor = [0.8 0.4 0.1]; % Colors the part in an NX-like orange tone.
p.EdgeColor = 'none';        % Hides the triangle edges for a smooth surface look.

% Lighting and camera adjustments for better rendering quality
camlight('headlight');  % Attaches a light source to the camera's position.
lighting gouraud;       % Ensures soft light distribution across curved surfaces.
material shiny;         % Applies a slight metallic gloss to the part.
axis equal;             % Equalizes the X, Y, and Z axis scales so the part isn't distorted.
grid on;                % Enables grid lines in the 3D space.
view(3);                % Sets the camera to a standard 3D isometric view.

% Axis labels (Noting that the Intermediate axis is Y)
xlabel('X Axis'); ylabel('Y Axis (Intermediate)'); zlabel('Z Axis');

% Fixing spatial limits so the screen doesn't constantly rescale during the flip.
xlim([-80 80]); ylim([-80 80]); zlim([-80 80]);

% hgtransform: MATLAB's transformation object used for dynamic animations.
% We make the part (p) a child of this object (tform). Wherever tform rotates, the part follows.
tform = hgtransform;
p.Parent = tform;

% =========================================================================
% ATTACHING ROTATING AXES TO THE PART (Matching Plot Colors)
% =========================================================================
% Length of the axis lines (50 units looks well-proportioned to the part size)
L = 50; 

% X Axis (Red - Min Axis)
% line([x_start x_end], [y_start y_end], [z_start z_end])
line_x = line([0 L], [0 0], [0 0], 'Color', 'r', 'LineWidth', 2, 'Parent', tform);
text(L+5, 0, 0, 'X', 'Color', 'r', 'FontSize', 14, 'FontWeight', 'bold', 'Parent', tform);

% Y Axis (Green - INTERMEDIATE AXIS)
line_y = line([0 0], [0 L], [0 0], 'Color', 'g', 'LineWidth', 2, 'Parent', tform);
text(0, L+5, 0, 'Y', 'Color', 'g', 'FontSize', 14, 'FontWeight', 'bold', 'Parent', tform);

% Z Axis (Blue - Max Axis)
line_z = line([0 0], [0 0], [0 L], 'Color', 'b', 'LineWidth', 2, 'Parent', tform);
text(0, 0, L+5, 'Z', 'Color', 'b', 'FontSize', 14, 'FontWeight', 'bold', 'Parent', tform);

% =========================================================================
% DYNAMIC ANGULAR MOMENTUM ARROW (PREPARATION)
% =========================================================================
hold on; 
% We create an empty arrow and text object here and save their "handles" (h_arrow, h_text).
% We will calculate and update their data INSIDE the loop at every single millisecond.
h_arrow = quiver3(0, 0, 0, 0, 0, 0, 0, 'Color', 'm', 'LineWidth', 3, 'MaxHeadSize', 0.5);
h_text = text(0, 0, 0, 'H', 'Color', 'm', 'FontSize', 14, 'FontWeight', 'bold');
L_H = 65; % Length of the arrow on screen

% =========================================================================
% 5. LIVE PLOT SETUP (PRE-LOOP PREPARATION)
% =========================================================================
disp('Animation Starting!');
pause(2); % Pauses for 2 seconds to allow both windows to fully render before starting.

% Opens a second window (plot screen) to monitor angular velocities live.
fig2 = figure('Name', 'Live Graph', 'Color', 'w', 'Position', [880 100 800 600]);

% Creates 3 empty lines using NaN (Not a Number) since there's no data to plot yet.
% Colors: r=Red (X), g=Green (Y), b=Blue (Z).
line_wx = plot(NaN, NaN, 'r', 'LineWidth', 2); hold on;
line_wy = plot(NaN, NaN, 'g', 'LineWidth', 2);
line_wz = plot(NaN, NaN, 'b', 'LineWidth', 2);

% =========================================================================
% EMPTY LINES FOR ENERGY AND MOMENTUM
% =========================================================================
% Using dashed lines ('--') to distinguish them from the solid velocity lines.
% Black (k) for Energy, Magenta (m) for Momentum.
line_E = plot(NaN, NaN, 'c--', 'LineWidth', 2); 
line_H = plot(NaN, NaN, 'm--', 'LineWidth', 2);

% Visual enhancements for a professional plot appearance
grid on; % Adds a background grid
set(gca, 'FontSize', 11, 'LineWidth', 1);
title('Live Graph', 'FontSize', 14);
xlabel('Time (seconds)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Angular Velocity (rad/s)', 'FontSize', 12, 'FontWeight', 'bold');

% Updated legend to include the scaled Conservation lines
legend('\omega_x (Min Axis)', '\omega_y (Int. Axis)', '\omega_z (Max Axis)', ...
    'Kinetic Energy (E/10)', 'Angular Momentum (||H||/5)', 'Location', 'best');


% CRITICAL POINT: Fixing the plot limits in advance.
% Time axis goes from 0 to the final calculated second (t(end)).
% Velocity axis is set between -20 and +20 rad/s. If not fixed, the graph will stutter.
xlim([0 t(end)]); 
ylim([-20 20]); 

% =========================================================================
% 6. ANIMATION LOOP (WHERE TIME FLOWS)
% =========================================================================
% This loop runs once for every single time step (frame) calculated by ode45.
for i = 1:length(t)
    
    % Step 1: Extract the orientation (quaternion) at the current time step from matrix Y.
    % Columns 4, 5, 6, and 7 of matrix Y hold q0, q1, q2, and q3 respectively.
    q = Y(i, 4:7);
    
    % In long simulations, numerical rounding errors accumulate, causing the object to scale up.
    % We prevent this by dividing the quaternion by its length (normalizing it to a Unit Vector).
    q = q / norm(q); 
    
    % Assigning quaternion components to individual variables (for formula readability)
    q0 = q(1); q1 = q(2); q2 = q(3); q3 = q(4);
    
    % Step 2: Converting the Quaternion to a Standard Rotation Matrix
    % The graphics engine doesn't understand 4D math; it requires a 4x4 transformation matrix.
    % This long equation is the standard formula mapping a quaternion to a rotation matrix.
    R = [1 - 2*q2^2 - 2*q3^2,   2*q1*q2 - 2*q0*q3,   2*q1*q3 + 2*q0*q2, 0;
         2*q1*q2 + 2*q0*q3,     1 - 2*q1^2 - 2*q3^2, 2*q2*q3 - 2*q0*q1, 0;
         2*q1*q3 - 2*q0*q2,     2*q2*q3 + 2*q0*q1,   1 - 2*q1^2 - 2*q2^2, 0;
         0, 0, 0, 1];
         
    % Applying the prepared rotation matrix (R) to our transformation object.
    % This instantly rotates the part to its new posture in the virtual space.
    tform.Matrix = R;

    % --- DYNAMIC ANGULAR MOMENTUM CALCULATION (LIVE) ---
    % 1. Calculate current angular momentum in the rotating BODY frame.
    % This vector dances and changes constantly as velocities flip.
    H_body = [I(1)*Y(i, 1); I(2)*Y(i, 2); I(3)*Y(i, 3)];

    % 2. Transform it to the fixed INERTIAL frame using the 3x3 Rotation Matrix R.
    % This proves the Transport Theorem live!
    H_inertial = R(1:3, 1:3) * H_body;

    % 3. Normalize to keep the arrow length visually constant on screen.
    H_dir = H_inertial / norm(H_inertial);

    % 4. Inject the newly calculated coordinates into the arrow object!
    set(h_arrow, 'UData', H_dir(1)*L_H, 'VData', H_dir(2)*L_H, 'WData', H_dir(3)*L_H);
    set(h_text, 'Position', [H_dir(1)*L_H + 5, H_dir(2)*L_H, H_dir(3)*L_H]);
    
    % Step 3: Updating the Live Plot
    % We inject the X (time) and Y (velocity) data from the beginning up to the current 
    % time 'i' into the "empty" lines we created before the loop.
    % This makes the lines draw themselves smoothly from left to right.
    set(line_wx, 'XData', t(1:i), 'YData', Y(1:i, 1));
    set(line_wy, 'XData', t(1:i), 'YData', Y(1:i, 2));
    set(line_wz, 'XData', t(1:i), 'YData', Y(1:i, 3));

    % --- DYNAMIC CONSERVATION LAWS PLOTTING (LIVE CALCULATION) ---
    % 1. Extract the LIVE velocity history up to the current frame 'i'
    w_x_live = Y(1:i, 1);
    w_y_live = Y(1:i, 2);
    w_z_live = Y(1:i, 3);

    % 2. Calculate Energy and Momentum dynamically for the drawn frames!
    % This forces MATLAB to prove the conservation live, rather than drawing a static line.
    E_live = 0.5 * (I(1)*w_x_live.^2 + I(2)*w_y_live.^2 + I(3)*w_z_live.^2);
    H_live = sqrt((I(1)*w_x_live).^2 + (I(2)*w_y_live).^2 + (I(3)*w_z_live).^2);

    % 3. Scale them down so they fit beautifully in the [-20 20] plot limit!
    % Real E is ~126 Joules -> scaled to ~12.6
    % Real H is ~50.5 magnitude -> scaled to ~10.1
    E_scaled = E_live / 10;
    H_scaled = H_live / 5;

    % 4. Inject the dynamically calculated and scaled values into the plot!
    set(line_E, 'XData', t(1:i), 'YData', E_scaled);
    set(line_H, 'XData', t(1:i), 'YData', H_scaled);
    
    % Step 4: Render to Screen!
    % Tells MATLAB: "Stop background calculations and immediately display this current frame."
    % This command creates the fluid animation effect rather than a static image.
    drawnow;
    
    % We pause for 0.01 seconds (10 ms) between frames to control playback speed.
    % This is crucial to observe the Dzhanibekov flip cinematically and clearly.
    pause(0.008); 
end
disp('Animation Finished!'); % Prints to the console once the loop is fully complete.

% =========================================================================
% DYNAMICS FUNCTION (Euler's Rigid Body Equations - THE HEART OF THE PHYSICS)
% =========================================================================
% This function is called repeatedly by the 'ode45' solver every millisecond.
% Its core purpose: "Given these current velocities, what is the system's acceleration?"
function dy = rigidBodyDynamics(~, y, I)
    % Separating velocities and the quaternion from the current state vector (y).
    w = y(1:3); % w(1)=X velocity, w(2)=Y velocity, w(3)=Z velocity
    q = y(4:7); % Quaternion components
    
    % 1. Calculating Angular Accelerations (Euler Equations)
    % Since net external torque is ZERO, angular acceleration (dw) is dictated purely by inertia.
    % The cross-multiplication of velocities (e.g., w(2)*w(3)) creates the intermediate axis instability.
    dw = zeros(3,1); % Pre-allocating an empty 3x1 acceleration vector
    dw(1) = (I(2) - I(3)) * w(2) * w(3) / I(1); % X-axis acceleration
    dw(2) = (I(3) - I(1)) * w(3) * w(1) / I(2); % Y-axis acceleration (Intermediate axis acceleration)
    dw(3) = (I(1) - I(2)) * w(1) * w(2) / I(3); % Z-axis acceleration
    
    % 2. Quaternion Derivative (Kinematics)
    % We have angular velocities, but how does the spatial "orientation" change?
    % The matrix W is a special skew-symmetric cross-product matrix containing the velocities.
    W = [ 0,    -w(1), -w(2), -w(3);
          w(1),  0,     w(3), -w(2);
          w(2), -w(3),  0,     w(1);
          w(3),  w(2), -w(1),  0];
    
    % The time derivative of orientation (dq/dt) is found using this standard formula.
    dq = 0.5 * W * q;
    
    % We concatenate the found acceleration (dw) and orientation change (dq) back into 
    % a single 'dy' (change) column vector to send back to the ode45 solver.
    dy = [dw; dq];
end
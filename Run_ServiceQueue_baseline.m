%[text] # Chucktown UrgentCare Simulation
%[text] Savannah Jellings and Natalie Huey
%[text] April 22nd 2026
%[text] The following block of code collects statistics and plot histograms along the way.
PictureFolder = "Pictures";
mkdir(PictureFolder);
%%
%[text] ## Set up
%[text] We'll measure time in hours
%[text] #### Patient arrival rate: 2 per hour
lambda = 2;
%[text] #### Departure (service/treatment) rate: 1 patient per 20 minutes, so 3 patients per hour
mu = 3;
%[text] #### Number of doctors:
s = 1;
%[text] Run many samples of the queue:
NumSamples = 20;
%[text] Each sample is run up to a maximum time, in our case, each shift is 8 hours:
MaxTime = 8;
%[text] Make a log entry every so often (one a minute): 
LogInterval = 1/60;
%%
%[text] ## Numbers from theory for M/M/1 queue
%[text] Compute `P(1+n)` = $P\_n$ = probability of finding the system in state $n$ in the long term. Note that this calculation assumes $s=1$.
rho = lambda / mu;
P0 = 1 - rho;
nMax = 10;
P = zeros([1, nMax+1]);
P(1) = P0;
for n = 1:nMax
    P(1+n) = P0 * rho^n;
end
%%
%[text] ## Run simulation samples
%[text] This is the most time consuming calculation in the script, so let's put it in its own section.  That way, we can run it once, and more easily run the faster calculations multiple times as we add features to this script.
%[text] Reset the random number generator.  This causes MATLAB to use the same sequence of pseudo-random numbers each time you run the script, which means the results come out exactly the same.  This is a good idea for testing purposes.  Under other circumstances, you probably want the random numbers to be truly unpredictable and you wouldn't do this.
rng("default");
%[text] We'll store our queue simulation objects in this list.
QSamples = cell([NumSamples, 1]);
%[text] The statistics come out weird if the log interval is too short, because the log entries are not independent enough.  So the log interval should be long enough for several arrival and departure events happen.
for SampleNum = 1:NumSamples
    if mod(SampleNum, 10) == 0
        fprintf("%d ", SampleNum);
    end
    if mod(SampleNum, 100) == 0
        fprintf("\n");
    end
    q = ServiceQueue( ...
        ArrivalRate=lambda, ...
        DepartureRate=mu, ...
        NumServers=s, ...
        LogInterval=LogInterval);
    q.schedule_event(Arrival(random(q.InterArrivalDist), Customer(1)));
    run_until(q, MaxTime);
    QSamples{SampleNum} = q;
end
%%
%[text] ## Collect measurements of how many customers are in the system
%[text] Count how many customers are in the system at each log entry for each sample run.  There are two ways to do this.  You only have to do one of them.
%[text] ### Option one: Use a for loop.
%[text] #### Compute simulation $L$ (patients in the system):
NumInSystemSamples = cell([NumSamples, 1]);
for SampleNum = 1:NumSamples
    q = QSamples{SampleNum};
    % Pull out samples of the number of customers in the queue system. Each
    % sample run of the queue results in a column of samples of customer
    % counts, because tables like q.Log allow easy extraction of whole
    % columns like this.
    NumInSystemSamples{SampleNum} = q.Log.NumWaiting + q.Log.NumInService;
end
%[text] #### Compute simulation $L\_q$ (expected number of patients waiting):
NumWaitingSamples = cell([NumSamples, 1]);
for SampleNum = 1:NumSamples
    q = QSamples{SampleNum};
    NumWaitingSamples{SampleNum} = q.Log.NumWaiting;
end
%[text] #### Compute the count of patients served per shift:
CountServed = cell([NumSamples,1]);
for SampleNum = 1:NumSamples
    q= QSamples{SampleNum};
    CountServed{SampleNum} = numel(q.Served);
end
%[text] ### Option two: Map a function over the cell array of ServiceQueue objects.
%[text] The `@(q) ...` expression is shorthand for a function that takes a `ServiceQueue` as input, names it `q`, and computes the sum of two columns from its log.  The `cellfun` function applies that function to each item in `QSamples`. The option `UniformOutput=false` tells `cellfun` to produce a cell array rather than a numerical array.
NumInSystemSamples = cellfun( ...
    @(q) q.Log.NumWaiting + q.Log.NumInService, ...
    QSamples, ...
    UniformOutput=false);
%[text] ## Join numbers from all sample runs.
%[text] `vertcat` is short for "vertical concatenate", meaning it joins a bunch of arrays vertically, which in this case results in one tall column.
NumInSystem = vertcat(NumInSystemSamples{:});

NumWaiting = vertcat(NumWaitingSamples{:});

CountServed2 = vertcat(CountServed{:});
%[text] MATLAB-ism: When you pull multiple items from a cell array, the result is a "comma-separated list" rather than some kind of array.  Thus, the above means
%[text] `NumInSystem = vertcat(NumInSystemSamples{1}, NumInSystemSamples{2}, ...)`
%[text] which concatenates all the columns of numbers in NumInSystemSamples into one long column.
%[text] This is roughly equivalent to "splatting" in Python, which looks like `f(*args)`.
%%
%[text] ## Pictures and stats for number of customers in system
%[text] #### Print out mean number of patients in the system and mean number of patients waiting: 
meanNumInSystem = mean(NumInSystem);
fprintf("Mean number in system: %f\n", meanNumInSystem);
meanNumWaiting = mean(NumWaiting);
fprintf("Mean number waiting: %f\n", meanNumWaiting);
%[text] Make a figure with one set of axes.
fig = figure();
t = tiledlayout(fig,1,1);
ax = nexttile(t);
%[text] MATLAB-ism: Once you've created a picture, you can use `hold` to cause further plotting functions to work with the same picture rather than create a new one.
hold(ax, "on");
%[text] Start with a histogram.  The result is an empirical PDF, that is, the area of the bar at horizontal index n is proportional to the fraction of samples for which there were n customers in the system.  The data for this histogram is counts of customers, which must all be whole numbers.  The option `BinMethod="integers"` means to use bins $(-0.5, 0.5), (0.5, 1.5), \\dots$ so that the height of the first bar is proportional to the count of 0s in the data, the height of the second bar is proportional to the count of 1s, etc. MATLAB can choose bins automatically, but since we know the data consists of whole numbers, it makes sense to specify this option so we get consistent results.
%[text] ## Histogram of Count of Patients in the System:
h = histogram(ax, NumInSystem, Normalization="probability", BinMethod="integers");
%[text] Plot $(0, P\_0), (1, P\_1), \\dots$.  If all goes well, these dots should land close to the tops of the bars of the histogram.
plot(ax, 0:nMax, P, 'o', MarkerEdgeColor='k', MarkerFaceColor='r');
%[text] Add titles and labels and such.
title(ax, "Number of customers in the system");
xlabel(ax, "Count");
ylabel(ax, "Probability");
legend(ax, "simulation", "theory");
%[text] Set ranges on the axes. MATLAB's plotting functions do this automatically, but when you need to compare two sets of data, it's a good idea to use the same ranges on the two pictures.  To start, you can let MATLAB choose the ranges automatically, and just know that it might choose very different ranges for different sets of data.  Once you're certain the picture content is correct, choose an x range and a y range that gives good results for all sets of data.  The final choice of ranges is a matter of some trial and error.  You generally have to do these commands *after* calling `plot` and `histogram`.
%[text] This sets the vertical axis to go from $0$ to $0.2$.
ylim(ax, [0, 0.4]);
%[text] This sets the horizontal axis to go from $-1$ to $21$.  The histogram will use bins $(-0.5, 0.5), (0.5, 1.5), \\dots$ so this leaves some visual breathing room on the left.
xlim(ax, [-1, 21]);
%[text] MATLAB-ism: You have to wait a couple of seconds for those settings to take effect or `exportgraphics` will screw up the margins.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Number in system histogram.pdf");
exportgraphics(fig, PictureFolder + filesep + "Number in system histogram.svg");
%%
%[text] ## Histogram of the count of patients waiting:
fig = figure();
t = tiledlayout(fig,1,1);
ax = nexttile(t);
h = histogram(ax, NumWaiting, Normalization="probability", BinMethod="integers");
title(ax, "Number of customers waiting");
xlabel(ax, "Count");
ylabel(ax, "Probability");
%[text] Set ranges on the axes.
ylim(ax, [0, 1.0]);
xlim(ax, [-1, 20]);
%[text] Wait for MATLAB to catch up.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf");
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg");
%%
%[text] ## Histogram of count of patients served per shift:
fig = figure();
t = tiledlayout(fig,1,1);
ax = nexttile(t);
h = histogram(ax, CountServed2, Normalization="probability", BinMethod="integers");
title(ax, "Number of customers served per shift");
xlabel(ax, "Count");
ylabel(ax, "Probability");
%[text] Set ranges on the axes.
ylim(ax, [0, 1.0]);
xlim(ax, [6, 24]);
%[text] Wait for MATLAB to catch up.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf");
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg");
%%
%[text] ## Collect measurements of how long customers spend in the system
%[text] This is a rather different calculation because instead of looking at log entries for each sample `ServiceQueue`, we'll look at the list of served  customers in each sample `ServiceQueue`.
%[text] ### Option one: Use a for loop.
%[text] #### Compute $W$ (Time patients spend in the system): 
TimeInSystemSamples = cell([NumSamples, 1]);
for SampleNum = 1:NumSamples
    q = QSamples{SampleNum};
    % The next command has many parts.
    %
    % q.Served is a row vector of all customers served in this particular
    % sample.
    % The ' on q.Served' transposes it to a column.
    %
    % The @(c) ... expression below says given a customer c, compute its
    % departure time minus its arrival time, which is how long c spent in
    % the system.
    %
    % cellfun(@(c) ..., q.Served') means to compute the time each customer
    % in q.Served spent in the system, and build a column vector of the
    % results.
    %
    % The column vector is stored in TimeInSystemSamples{SampleNum}.
    TimeInSystemSamples{SampleNum} = ...
        cellfun(@(c) c.DepartureTime - c.ArrivalTime, q.Served');
end
%[text] #### Compute $W\_q$ (time patients spend waiting):
% Compute simulation W_q
TimeWaitingSamples = cell([NumSamples, 1]);
for SampleNum = 1:NumSamples
    q = QSamples{SampleNum};
    TimeWaitingSamples{SampleNum} = cellfun(@(c) c.BeginServiceTime - c.ArrivalTime, q.Served');
end
%[text] ### Option two: Use `cellfun` twice.
%[text] The outer call to `cellfun` means do something to each `ServiceQueue` object in `QSamples`.  The "something" it does is to look at each customer in the `ServiceQueue` object's list `q.Served` and compute the time it spent in the system.
TimeInSystemSamples = cellfun( ...
    @(q) cellfun(@(c) c.DepartureTime - c.ArrivalTime, q.Served'), ...
    QSamples, ...
    UniformOutput=false);
%[text] ### Join them all into one big column.
TimeInSystem = vertcat(TimeInSystemSamples{:});

TimeWaiting = vertcat(TimeWaitingSamples{:});
%[text] #### Calculate the time that customers are being served for (total time in system - time spent waiting):
TimeServed = TimeInSystem - TimeWaiting;
%%
%[text] ## Pictures and stats for time customers spend in the system
%[text] Print out mean time spent in the system.
meanTimeInSystem = mean(TimeInSystem);
fprintf("Mean time in system: %f\n", meanTimeInSystem);

meanTimeWaiting = mean(TimeWaiting);
fprintf("Mean time waiting: %f\n", meanTimeWaiting);
%[text] Make a figure with one set of axes.
fig = figure();
t = tiledlayout(fig,1,1);
ax = nexttile(t);
%[text] This time, the data is a list of real numbers, not integers.  The option `BinWidth=...` means to use bins of a particular width, and choose the left-most and right-most edges automatically.  Instead, you could specify the left-most and right-most edges explicitly.  For instance, using `BinEdges=0:0.5:60` means to use bins $(0, 0.5), (0.5, 1.0), \\dots$
%[text] ## Histogram for time patients spend in the system:
h = histogram(ax, TimeInSystem, Normalization="probability", BinWidth=5/60);
%[text] Add titles and labels and such.
title(ax, "Time in the system");
xlabel(ax, "Time");
ylabel(ax, "Probability");
%[text] Set ranges on the axes.
ylim(ax, [0, 0.2]);
xlim(ax, [0, 10]);
%[text] Wait for MATLAB to catch up.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf");
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg");
%%
%[text] ## Histogram for time patients spend waiting in the queue: 
fig = figure();
t = tiledlayout(fig,1,1);
ax = nexttile(t);
h = histogram(ax, TimeWaiting, Normalization="probability", BinWidth=5/60);
title(ax, "Time spent waiting");
xlabel(ax, "Time");
ylabel(ax, "Probability");
%[text] Set ranges on the axes.
ylim(ax, [0, 1.0]);
xlim(ax, [0, 5]);
%[text] Wait for MATLAB to catch up.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf");
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg");
%%
%[text] ## Histogram for time patients spend being served:
fig = figure();
t = tiledlayout(fig,1,1);
ax = nexttile(t);
h = histogram(ax, TimeServed, Normalization="probability", BinWidth=5/60);
title(ax, "Time Customers Spent Being Served");
xlabel(ax, "Time");
ylabel(ax, "Probability");
%[text] Set ranges on the axes.
ylim(ax, [0, 1.0]);
xlim(ax, [0, 5]);
%[text] Wait for MATLAB to catch up.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf");
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg");
%%
%[text] # Part 2:
%[text] **1)** From theory we compute the probabilities $P\_0=\\frac{1}{3}$, $P\_1=\\frac{2}{9}$, $P\_2=\\frac{4}{27}$, $P\_3=\\frac{8}{81}$, $P\_4=\\frac{16}{243}$, and $P\_5=\\frac{32}{729}$. 
%[text] The theory computations are $L=2$, $L\_q=\\frac{4}{3}$.
%[text]  From theory in hours we get $W=1$ and $W\_q=\\frac{2}{3}$. The theory computations in minutes are $W=60$ and $W\_q=40$.
%[text] **3)** The simulation values are $L=1.697$, $L\_q=1.085$ and $W=0.732$, $W\_q=0.419$ in hours. These values are pretty close to the theoretical numbers, all come out to be a little bit lower than the theory. 

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"onright","rightPanelPercent":35.3}
%---

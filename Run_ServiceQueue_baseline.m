%[text] # Run samples of the UrgentCare simulation
%[text] Savannah Jellings and Natalie Huey
%[text] April 22nd 2026
%[text] Collect statistics and plot histograms along the way.
PictureFolder = "Pictures";
mkdir(PictureFolder); %[output:8a8221c0]
%%
%[text] ## Set up
%[text] We'll measure time in hours
%[text] Arrival rate: 2 per hour
lambda = 2;
%[text] Departure (service) rate: 1 per 20 minutes, so 3 per hour
mu = 3;
%[text] Number of doctors:
s = 1;
%[text] Run many samples of the queue.
NumSamples = 20;
%[text] Each sample is run up to a maximum time.
MaxTime = 8;
%[text] Make a log entry every so often
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
for SampleNum = 1:NumSamples %[output:group:6fb3ae41]
    if mod(SampleNum, 10) == 0
        fprintf("%d ", SampleNum); %[output:8895bdc0]
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
end %[output:group:6fb3ae41]
%%
%[text] ## Collect measurements of how many customers are in the system
%[text] Count how many customers are in the system at each log entry for each sample run.  There are two ways to do this.  You only have to do one of them.
%[text] ### Option one: Use a for loop.
NumInSystemSamples = cell([NumSamples, 1]);
for SampleNum = 1:NumSamples
    q = QSamples{SampleNum};
    % Pull out samples of the number of customers in the queue system. Each
    % sample run of the queue results in a column of samples of customer
    % counts, because tables like q.Log allow easy extraction of whole
    % columns like this.
    NumInSystemSamples{SampleNum} = q.Log.NumWaiting + q.Log.NumInService;
end

% Compute simulation L_q
NumWaitingSamples = cell([NumSamples, 1]);
for SampleNum = 1:NumSamples
    q = QSamples{SampleNum};
    NumWaitingSamples{SampleNum} = q.Log.NumWaiting;
end

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
%[text] Print out mean number of customers in the system.
meanNumInSystem = mean(NumInSystem);
fprintf("Mean number in system: %f\n", meanNumInSystem); %[output:1ce00f8c]

meanNumWaiting = mean(NumWaiting);
fprintf("Mean number waiting: %f\n", meanNumWaiting); %[output:594a44f6]
%[text] Make a figure with one set of axes.
fig = figure(); %[output:4ba7ccc7]
t = tiledlayout(fig,1,1); %[output:4ba7ccc7]
ax = nexttile(t); %[output:4ba7ccc7]
%[text] MATLAB-ism: Once you've created a picture, you can use `hold` to cause further plotting functions to work with the same picture rather than create a new one.
hold(ax, "on"); %[output:4ba7ccc7]
%[text] Start with a histogram.  The result is an empirical PDF, that is, the area of the bar at horizontal index n is proportional to the fraction of samples for which there were n customers in the system.  The data for this histogram is counts of customers, which must all be whole numbers.  The option `BinMethod="integers"` means to use bins $(-0.5, 0.5), (0.5, 1.5), \\dots$ so that the height of the first bar is proportional to the count of 0s in the data, the height of the second bar is proportional to the count of 1s, etc. MATLAB can choose bins automatically, but since we know the data consists of whole numbers, it makes sense to specify this option so we get consistent results.
h = histogram(ax, NumInSystem, Normalization="probability", BinMethod="integers"); %[output:4ba7ccc7]
%[text] Plot $(0, P\_0), (1, P\_1), \\dots$.  If all goes well, these dots should land close to the tops of the bars of the histogram.
plot(ax, 0:nMax, P, 'o', MarkerEdgeColor='k', MarkerFaceColor='r'); %[output:4ba7ccc7]
%[text] Add titles and labels and such.
title(ax, "Number of customers in the system"); %[output:4ba7ccc7]
xlabel(ax, "Count"); %[output:4ba7ccc7]
ylabel(ax, "Probability"); %[output:4ba7ccc7]
legend(ax, "simulation", "theory"); %[output:4ba7ccc7]
%[text] Set ranges on the axes. MATLAB's plotting functions do this automatically, but when you need to compare two sets of data, it's a good idea to use the same ranges on the two pictures.  To start, you can let MATLAB choose the ranges automatically, and just know that it might choose very different ranges for different sets of data.  Once you're certain the picture content is correct, choose an x range and a y range that gives good results for all sets of data.  The final choice of ranges is a matter of some trial and error.  You generally have to do these commands *after* calling `plot` and `histogram`.
%[text] This sets the vertical axis to go from $0$ to $0.2$.
ylim(ax, [0, 0.4]); %[output:4ba7ccc7]
%[text] This sets the horizontal axis to go from $-1$ to $21$.  The histogram will use bins $(-0.5, 0.5), (0.5, 1.5), \\dots$ so this leaves some visual breathing room on the left.
xlim(ax, [-1, 21]); %[output:4ba7ccc7]
%[text] MATLAB-ism: You have to wait a couple of seconds for those settings to take effect or `exportgraphics` will screw up the margins.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Number in system histogram.pdf"); %[output:4ba7ccc7]
exportgraphics(fig, PictureFolder + filesep + "Number in system histogram.svg"); %[output:4ba7ccc7]
%%
fig = figure(); %[output:8158a368]
t = tiledlayout(fig,1,1); %[output:8158a368]
ax = nexttile(t); %[output:8158a368]
h = histogram(ax, NumWaiting, Normalization="probability", BinMethod="integers"); %[output:8158a368]
title(ax, "Number of customers waiting"); %[output:8158a368]
xlabel(ax, "Count"); %[output:8158a368]
ylabel(ax, "Probability"); %[output:8158a368]
%[text] Set ranges on the axes.
ylim(ax, [0, 1.0]); %[output:8158a368]
xlim(ax, [-1, 20]); %[output:8158a368]
%[text] Wait for MATLAB to catch up.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf"); %[output:8158a368]
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg"); %[output:8158a368]
%%
fig = figure(); %[output:35a8387b]
t = tiledlayout(fig,1,1); %[output:35a8387b]
ax = nexttile(t); %[output:35a8387b]
h = histogram(ax, CountServed2, Normalization="probability", BinMethod="integers"); %[output:35a8387b]
title(ax, "Number of customers served per shift"); %[output:35a8387b]
xlabel(ax, "Count"); %[output:35a8387b]
ylabel(ax, "Probability"); %[output:35a8387b]
%[text] Set ranges on the axes.
ylim(ax, [0, 1.0]); %[output:35a8387b]
xlim(ax, [6, 24]); %[output:35a8387b]
%[text] Wait for MATLAB to catch up.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf"); %[output:35a8387b]
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg"); %[output:35a8387b]
%%
%[text] ## Collect measurements of how long customers spend in the system
%[text] This is a rather different calculation because instead of looking at log entries for each sample `ServiceQueue`, we'll look at the list of served  customers in each sample `ServiceQueue`.
%[text] ### Option one: Use a for loop.
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

TimeServed = TimeInSystem - TimeWaiting;
%%
%[text] ## Pictures and stats for time customers spend in the system
%[text] Print out mean time spent in the system.
meanTimeInSystem = mean(TimeInSystem);
fprintf("Mean time in system: %f\n", meanTimeInSystem); %[output:52433d72]

meanTimeWaiting = mean(TimeWaiting);
fprintf("Mean time waiting: %f\n", meanTimeWaiting); %[output:06f8901e]
%[text] Make a figure with one set of axes.
fig = figure(); %[output:64c9912c]
t = tiledlayout(fig,1,1); %[output:64c9912c]
ax = nexttile(t); %[output:64c9912c]
%[text] This time, the data is a list of real numbers, not integers.  The option `BinWidth=...` means to use bins of a particular width, and choose the left-most and right-most edges automatically.  Instead, you could specify the left-most and right-most edges explicitly.  For instance, using `BinEdges=0:0.5:60` means to use bins $(0, 0.5), (0.5, 1.0), \\dots$
h = histogram(ax, TimeInSystem, Normalization="probability", BinWidth=5/60); %[output:64c9912c]
%[text] Add titles and labels and such.
title(ax, "Time in the system"); %[output:64c9912c]
xlabel(ax, "Time"); %[output:64c9912c]
ylabel(ax, "Probability"); %[output:64c9912c]
%[text] Set ranges on the axes.
ylim(ax, [0, 0.2]); %[output:64c9912c]
xlim(ax, [0, 10]); %[output:64c9912c]
%[text] Wait for MATLAB to catch up.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf"); %[output:64c9912c]
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg"); %[output:64c9912c]
%%
fig = figure(); %[output:195e258f]
t = tiledlayout(fig,1,1); %[output:195e258f]
ax = nexttile(t); %[output:195e258f]
h = histogram(ax, TimeWaiting, Normalization="probability", BinWidth=5/60); %[output:195e258f]
title(ax, "Time spent waiting"); %[output:195e258f]
xlabel(ax, "Time"); %[output:195e258f]
ylabel(ax, "Probability"); %[output:195e258f]
%[text] Set ranges on the axes.
ylim(ax, [0, 1.0]); %[output:195e258f]
xlim(ax, [0, 5]); %[output:195e258f]
%[text] Wait for MATLAB to catch up.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf"); %[output:195e258f]
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg"); %[output:195e258f]
%%
fig = figure(); %[output:075ecc54]
t = tiledlayout(fig,1,1); %[output:075ecc54]
ax = nexttile(t); %[output:075ecc54]
h = histogram(ax, TimeServed, Normalization="probability", BinWidth=5/60); %[output:075ecc54]
title(ax, "Time Customers Spent Being Served"); %[output:075ecc54]
xlabel(ax, "Time"); %[output:075ecc54]
ylabel(ax, "Probability"); %[output:075ecc54]
%[text] Set ranges on the axes.
ylim(ax, [0, 1.0]); %[output:075ecc54]
xlim(ax, [0, 5]); %[output:075ecc54]
%[text] Wait for MATLAB to catch up.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf"); %[output:075ecc54]
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg"); %[output:075ecc54]
%%
%[text] Part 2:
%[text] 1\) From theory we compute the probabilities $P\_0=\\frac{1}{3}$, $P\_1=\\frac{2}{9}$, $P\_2=\\frac{4}{27}$, $P\_3=\\frac{8}{81}$, $P\_4=\\frac{16}{243}$, and $P\_5=\\frac{32}{729}$. The theory computations are $L=2$, $L\_q=\\frac{4}{3}$. From theory in hours we get $W=1$ and $W\_q=\\frac{2}{3}$. The theory computations in minutes are $W=60$ and $W\_q=40$.
%[text] 3\) The simulation values are $L=1.697$, $L\_q=1.085$ and $W=0.732$, $W\_q=0.419$ in hours. These values are pretty close to the theoretical numbers.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"onright","rightPanelPercent":35.3}
%---
%[output:8a8221c0]
%   data: {"dataType":"warning","outputData":{"text":"Warning: Directory already exists."}}
%---
%[output:8895bdc0]
%   data: {"dataType":"text","outputData":{"text":"10 20 ","truncated":false}}
%---
%[output:1ce00f8c]
%   data: {"dataType":"text","outputData":{"text":"Mean number in system: 1.697442\n","truncated":false}}
%---
%[output:594a44f6]
%   data: {"dataType":"text","outputData":{"text":"Mean number waiting: 1.084841\n","truncated":false}}
%---
%[output:4ba7ccc7]
%   data: {"dataType":"image","outputData":{"dataUri":"data:,","height":0,"width":0}}
%---
%[output:8158a368]
%   data: {"dataType":"image","outputData":{"dataUri":"data:,","height":0,"width":0}}
%---
%[output:35a8387b]
%   data: {"dataType":"image","outputData":{"dataUri":"data:,","height":0,"width":0}}
%---
%[output:52433d72]
%   data: {"dataType":"text","outputData":{"text":"Mean time in system: 0.732087\n","truncated":false}}
%---
%[output:06f8901e]
%   data: {"dataType":"text","outputData":{"text":"Mean time waiting: 0.418945\n","truncated":false}}
%---
%[output:64c9912c]
%   data: {"dataType":"image","outputData":{"dataUri":"data:,","height":0,"width":0}}
%---
%[output:195e258f]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAdQAAAEaCAYAAACoxaaoAAAAAXNSR0IArs4c6QAAIABJREFUeF7tnQmwFNX1hw+LIIgBJBFkCaIoaEoJAQtNxL9l4hJlkWjcYoQgECgKJAKiBqEwUIggKISg4IZRKEHcyi1ELQUXKASEUjaNQIVFBEo2oUTUf51L+tlvXvdMz3s9M\/d2f131Snnv9l2+c+b+5m7nVjvhhBO+Fx4IQAACEIAABKpEoBqCWiV+vAwBCEAAAhAwBBBUHAECEIAABCAQAwEENQaIZAEBCEAAAhBAUPEBCEAAAhCAQAwEENQYIJIFBCAAAQhAAEHFByAAAQhAAAIxEEBQY4BIFhCAAAQgAAEEFR+AAAQgAAEIxEAAQY0BIllAAAIQgAAEEFR8AAIQgAAEIBADAQQ1BohkAQEIQAACEEBQ8QEIQAACEIBADAQQ1BggkgUEIAABCEAAQcUHIAABCEAAAjEQQFBjgEgWEIAABCAAAQQVH4AABCAAAQjEQABBjQEiWUAAAhCAAAQQVHwAAhCAAAQgEAMBBDUGiGQBAQhAAAIQQFDxAQhAAAIQgEAMBBDUGCCSBQQgAAEIQABBxQdKTuDxxx+XNm3aRKrH+vXrTTpNf\/jwYZk+fbrMmzcv0rskikZgwoQJsmXLFpk2bVq0FwqcSutzwQUXmFLmzJlTrl6tWrWS0aNHy4wZM2Tp0qUmzTXXXCMDBw6UWrVqifpLr169ClxDsofAUQIIKp5QcgIIaslNYCqg4jRp0iRp2rRpBeEqZQ3DBNUTTv1iNXLkSAS1lEaibAQVH7CDQL6CyoijMHbLNhIsTImVz9Uv\/gcOHCgnqJXPlTchUDUCjFCrxo+3C0Bg0KBBcsMNN5icFy1aJCNGjChAKWSZSQBBxScgUDUCCGrV+PF2AQjkElRvROtfQ\/XEQEcrOm3Zr18\/M3WpT1A6r9qZa3KZU59eunzW4jp16iRjx46VevXqlaOT+eUgc61v+fLlZV8k9MWwMv18MtvnFeivw7Zt22TmzJkybNiwsjr5R3X+0V6mOXPx0bw1340bN5pX\/aLsb6+\/Pl67\/O33yg1aF88U+h07dpStkfrr67WpZcuWgWuomX5z+eWXl1u7z9VWLSuTZWb7C\/BxIEuHCCCoDhkrLVWtiqCGMdKOWn8yRU7T+zvSMDH0OlO\/eASVFSQS\/nR+kcmVNqhMv7hkE79s7fDe88RA\/+2tnUYRVE0T9KUmU5j9Xwj8bVUGuunJm4UI4ui3SdyCms1H\/JvcwhiqcOuGJ\/1BUNPSK0VrJ4IajROpikigqoLqH31lrs96HbW\/DH\/H76X355GrPn40QdOmfqHxj8AyBdWrR6YweSKcKUo6FR62lpgpBl7e\/t9njgbzmfL1M\/GYZrbHz9DLW8ucO3euXHzxxWYGwS9IYTbJxTRzDTVsl6\/fF8J8xP+Fx5\/e+30mVwS1iB2DA0UhqA4YKW1VzCVg2aZ8lZW\/UwzrpP2drtcpnnPOOWVThZnTs16ZuTpQfyeca5o4qA7e1GnQ3\/R4iB4XyiYgnrj5O\/7M9GHCmY+gBk3hhk1FL1u2rGwEnI1fmBAWQlD9I+CgcrPx87czlz+k7bOb9vYiqGn3AAvbX1VB9XeWYXllrjHqVG6XLl2yTkMqqlw7SjNFxcMb9F6285KZI089E9qzZ8+ydeEwswWNpLKtc2abWs11DjVzND9gwIAywfemRLU+zz77bNmactAms6A1XP+XkbgFNXNkHmSHbLYJ8h3vi5CFHyeqVEQCCGoRYVNUNAI2C2qUYBLZ1jn94lYIQQ2a2i2UoHp2UiazZ8+WK664wgi+imbjxo2NuGp9vM1W2aa7Mz0DQY32WSGVXQQQVLvsQW1ExAZBjeO4Ttimo6A10czp4Wwj1FyjZHWibKOoOKZ8M8vYtGmTEVMdmeqoVx\/ddKR13bdvX7n10hNPPLHcLuigKXcEla7ARQIIqotWS3idSyWo\/jXUXOuf+ZogaC3XL7jZ1kU9wfHWUKOMkoshqEFTtUFHVzxWHtMw+xZrDTXKlC9rqPl6OOmVAIKKH1hHoFSCqiD8x0eCdq9mE9qw3byab9D5zLBdvprev7kpaGeyfxo3aJNWMQQ1s13677Cdyvq3bDussx25KcUaaqYN2OVrXTdhZYUQVCvNku5KlUpQdWNJtrOhUUaGuc6Whq2hhlk8c\/0zW5hGv9hXRlCDNlQFBTvw1zWzvf6pcr8Q+kfg+ZyRVZuETVFnssg3sIN3qULYyJhzqOnuhyrT+tQKaoMGDeS+++6TGjVqcBtFZTyngO+UUlC1WUFTmfkcjwiLPJQ5us3syF955ZVyEYCiRkryj\/48s1RGUINGnLnWkrONysOOLGk5mWLlfVnp0KGDuVkmLLqVX+AzOXvvaP5Bt80EjeQ1bdQdvd4IXG+28SJh5eMXBfzIkLUlBFIpqCeddJKMGjVK2rVrJxs2bEBQLXHGtFWDa8bctHjQGVw3W0Kt4yaQKkGtWbOmdO3a1Qio7jT0r\/nEDZb8IJCLAIKai1Dp\/h4WrSpzFJ9rBF+6FlByKQikSlC9b5a6tX\/JkiVy2mmnmS39XAdWCtejTATVbh\/Idp5Yax7l+JLdLaR2cRNIlaB27NhRBg8eLLoZ4eOPPzY7Ovfv34+gxu1V5BeJAIIaCVNJE4VtMov7WFVJG0nhsRFIlaD6qXlTOghqbL5ERhCAAARSTQBBjThC1Y1M+sMDAQhAAAKFJ7B9+3bRH5ceBDWCoKqQjhw5Un7xi1+4ZFvqCgEIQMBZAitWrDDHk1wSVQQ1gqCqkOrFw64Zt5CfpPbt20ufPn1gkgEZLsFeBxe45NMfef6i54lVWF15ENQ8BNU14xbSCb0vGTApTxkuwV4HF7jk0x+56i8IKoKaj5+XpdVp8Msvv1w0uo9LUzKVamweL8ElGBZc4JLHx8gsr+msoGtf2BFUBDUfPyctBCAAgYITQFALjjjeAvI5NuOqceMlRm4QgAAEikPA1T43tSPUfNzCVePm00bSQgACELCFgKt9LoIawYNcNW6EppEEAhCAgHUEXO1zEdQIruSqcSM0jSQQgAAErCPgap+LoEZwJVeNG6FpJIEABCBgHQFX+1wENYIruWrcCE0jCQQgAAHrCLja5yKoEVzJVeNGaBpJIAABCFhHwNU+F0GN4EquGjdC00gCAQhAwDoCrva5CGoEV3LVuBGaRhIIQAAC1hFwtc9FUCO4kqvGjdA0kkAAAhCwjoCrfS6CGsGVXDVuhKaRBAIQgIB1BFztcxHUCK7kqnEjNI0kEIAABKwj4Gqfi6BGcCVXjRuhaSSBAAQgYB0BV\/tcBDWCK7lq3AhNIwkEIAAB6wi42uciqBFcyVXjRmgaSSAAAQhYR8DVPhdBjeBKrho3QtNIAgEIQMA6Aq72uQhqBFdy1bgRmkYSCEAAAtYRcLXPRVAjuJKrxo3QNJJAAAIQsI6Aq30ughrBlVw1boSmkQQCEICAdQRc7XMR1Aiu5KpxIzSNJBCAAASsI+Bqn4ugRnAlV40boWkkgQAEIGAdAVf7XAQ1giu5atwITSMJBCAAAesIuNrnIqgRXMlV40ZoGkkgAAEIWEfA1T4XQY3gSq4aN0LTSAIBCEDAOgKu9rkIagRXctW4EZpGEghAAALWEXC1z0VQI7iSq8aN0DSSQAACELCOgKt9LoIawZVcNW6EppEEAhCAgHUEXO1zEdQIruSqcSM0jSQQgAAErCPgap+LoEZwJVeNG6FpJIEABCBgHQFX+1wENYIruWrcCE0jCQQgAAHrCLja5yKoEVzJVeNGaBpJIAABCFhHwNU+F0GN4EquGjdC00gCAQhAwDoCrva5CGoEV3LVuBGaRhIIQAAC1hFwtc9FUCO4kqvGjdA0kkAAAhCwjoCrfS6CGsGVXDVuhKaRBAIQgIB1BFztcxHUCK7kqnEjNI0kEIAABKwj4GqfWzBB7dSpkwwfPlw+\/fRTmTNnjqxevdo6o0WtkKvGjdo+0kEAAhCwiYCrfW7BBFWBjB07Vho2bCjff\/+97Ny5U9544w2ZN2+efP755zbZLmddXDVuzoaRAAIQgICFBFztcwsmqGqjunXrysUXXyxdu3aV0047TWrVqiXffPONbN68Wf7973\/LM888IwcPHrTQnOWr5KpxrQdLBSEAAQgEEHC1zy2ooPo5qbh2795dLrnkEjnllFOMuH799deyZs0aM2p955135MiRI1Y6l6vGtRImlYIABCCQg4CrfW7RBDVTXH\/zm9\/I1VdfLaeeeqpUr15d9uzZI4sWLZLHH39ctm\/fbpXDuWpcqyBSGQhAAAIRCbja5xZVUP1TwK1bt5batWvLd999V7am2qRJEzMF\/OCDD8qCBQsioi98MleNW3gylAABCEAgfgKu9rkFF9QgEdVNSrt375Z3331Xnn32WdmwYYOxiE4HDxkyRA4dOiRXXXVV\/FaqZI6uGreSzeU1CEAAAiUl4GqfWzBBbdWqldx2221yxhlnmJGoPl999ZUsX75c5s+fLx988EGgwXTKt1mzZmYzky2Pq8a1hR\/1gAAEIJAPAVf73IIJqp5D1WMzuvlINx698MIL8vrrr+fceDRhwgTDfcSIEfnwL2haV41bUChkDgEIQKBABFztcwsmqCeddJJ06NBB3nzzzZxHY3TXr55NtfUIjavGLZCvky0EIACBghJwtc8tmKB6I9QXX3xRpk2bFgp\/0KBB0q1bNxk5cqQsXbq0oEaqbOauGrey7eU9CEAAAqUk4GqfG5ug6uajtm3byjHHHGPs0Lx5cxkwYICJjqSj1KCnZs2a0q9fP2natCmCWkrvpWwIQAACFhFIvaCqOI4bN04uuOCCvM3yySefiI5U9+7dm\/e7xXjBVeMWgw1lQAACEIibgKt9bmwjVAV6+umnS\/\/+\/aV+\/fpmpPrTn\/5Udu3aFSqUegZVg+c\/\/fTTsmnTprhtElt+rho3NgBkBAEIQKCIBFztc2MVVD9vBaLroq+++qrMmjWriKaIvyhXjRs\/CXKEAAQgUHgCrva5BRPUwiMvXgmuGrd4hCgJAhCAQHwEXO1zYxNUPSbTo0cPQ\/S5554z\/9V\/16lTJydljYyk79gWw9eruKvGzQmeBBCAAAQsJOBqnxuboHrHZNQ2OtWrjwZ2qFevXk5zHThwgF2+OSmRAAIQgEA6CKReUL1jM2rudevWGav7j9FkcwO9I1XfIbBDOj4stBICEIBANgKpF9Qku4erxk2yTWgbBCCQXAKu9rmxTfkm17Qirho3yTahbRCAQHIJuNrnxiao3hpqlDXTTDdgDTW5HwxaBgEIQCBfAqkXVO\/c6fHHH58vO9m\/f7\/ZwLRixYq83y3GC64atxhsKAMCEIBA3ARc7XNjG6HGDdSm\/Fw1rk0MqQsEIACBqARc7XMR1AgWdtW4EZpGEghAAALWEXC1z41NUAnsYJ1PUiEIQAACThJIvaAS2MFJv6XSEIAABKwjkHpBJbCDdT5JhSAAAQg4SSD1guqk1SJW2lXjRmweySAAAQhYRcDVPje2NdRs1jj77LPlyiuvlJYtW5Yl27x5szz\/\/POyevVqqwwZVBlXjWs9WCoIAQhAIICAq31uQQW1QYMGctddd8m5554r1atXr4Dt8OHD8tprr8nEiRPlyJEj1jqWq8a1FigVgwAEIJCFgKt9bkEF9fbbb5du3brJzp07zUXjK1euNAhr1qwp5513nvz617+W4447TubPny\/Tpk2z1sFcNa61QKkYBCAAAQQ1ug+0atVKJk2aJNWqVRMV1g0bNlR4+fTTT5d77rlH9LaZW265RT7\/\/PPoBRQxJYJaRNgUBQEIpJ6Aq31uwUao3jGaxYsXy9133x3qIKNGjZLOnTtzH2rqP0IAgAAEIHCUAIKa4Qnt2rWT8ePHy5o1a2TYsGGhfjJhwgQ566yz5I477pBVq1ZZ6U+uGtdKmFQKAhCAQA4Crva5BRuhKi8VSwWj66MvvvhiBYQXXnih3HbbbfLJJ5\/I0KFDrd2Y5Kpx+dRCAAIQcJGAq31ubILqhR6sU6dOmf1q1aplpnN149Gnn34qa9eule+\/\/978\/eSTTzYj00OHDskbb7whTz31lGzfvt1K27tqXCthUikIQAACjFCzE+A+VD4jEIAABCAQBwFXBzGxjVC90IPHHHNM3jx1l++6devk4MGDeb9bjBdcNW4x2FAGBCAAgbgJuNrnxiaocQPNlt9ll10m\/fr1k8aNG8u3334rW7dulYceekjeeuutrNVo0aKFTJkyRZo1a1Yh3fr166VXr16B77tq3GLahLIgAAEIxEXA1T63KIKqgRx+9rOfybHHHluBt665\/vznPzcRk3SUmuvRQBF6ZvW7776TpUuXir7foUMHM7odN26cvPvuu6FZeNPSum6rwSb8j4ZCDDve46pxc7Hk7xCAAARsJOBqn1tQQdXADSNHjpRTTz01MPSgZ8gDBw5EOoeqwjx9+nQ55ZRTTLjChQsXmiyuv\/566d+\/vyxfvlxuvfXWUP+47rrrZMCAAfLcc8\/J\/fffH9mPPOM+\/PDDZdGe9GXdRGXrRqrIjSMhBCAAAcsIIKgBBpk8ebIJMbhnzx7ZtWuX6JTrvn37ZO\/evaK7gnXdVadrX375ZZk3b17ONVTvbOuOHTukb9++ZcdsmjRpIg888IAJaahnXjdu3BjoHkOGDJEePXoYUdbyoj6ecTPTr1ixQsaOHYuoRgVJOghAAAIRCCCoGZDOOOMME1ZQA+APHjzYHJdR0dOpWRVDfVTgLr30Unn00Udl7ty5OTFfddVVJq8lS5bIiBEjyqWfOnWqnHnmmTJ69OjQaV8Nhag33yxbtkx0+lcFXcV+wYIFMnv27NBzsJ5xJ77woezYc3Tj1NknN5Kb\/q+NDBw4UFRYeSAAAQhAIB4CCGoGR2+98oMPPjBRkPRR0dMr3DS2r55JrV+\/fllQ\/EGDBpmRa7bnmmuuMQIWNGWrQST0Vpuw0aeWNWPGDNEYwzpaVlHVc7Jaz9q1a5ur5HREHfR4xh02+z1ZtXm3SdKuZSOZ1POXCGo8nx9ygQAEIFBGAEENEVQN2qAjVX1USPWGGQ1J+Oabb5rfaSxfFcIooQdvvPFG6dOnjxlRZt5Ok0tQW7dubTYt1ahRQ+68886yYP1qOB3V6nEfrYt+Ach8POM+8fZ6Wb1pt3y+95A0qV8HQaUDgAAEIBAjAV0K9H50\/41rM4AF25SkG4d0inXLli1mmlYfnepVUXzkkUfkiSeeML9Tce3YsWOkTUlVGaFms7knxv56+dNnrqF6wsoINcZPEllBAAKpJ3DzzTebQZP3IKg+l3jwwQdF11JfeeUVM6LUkaiODnVn7JgxY6R58+YyfPhws3bpTQNn86iqrqHqmqlO8+q6qf\/Rtdxrr71W5syZE3gva+YaKiPU1H\/uAQABCBSAgDc6bd++vRFWBNUH2Qt+r5GQVDA1CL4Kq5479R7drLRo0SLz91xPrl2+Om2ru3w\/++yzCll5o1u90cYbMXuJdG1X89b\/6nRy5sMaai7L8HcIQAAC8RFgDTWEpa5d6k5eFSq9QFy\/gWhgBhVVDc6ga5a6GShz1BiUXVXOoeqZWJ2C1jzuvffesqhKKvoq5vv37zdCG3SuFEGN74NCThCAAARyEUBQcxGK6e867as7gnXUmxkpyS+UmuaGG24wo1\/viI0Gfbjyyivlq6++kvfff79sl6+ObDV0YdjRHQQ1JuORDQQgAIEIBBDULJD07KcKmR6Z8R4N9adHVVavXh0Bb\/kkXbp0kd69e2eN5RskqDo67dmzp6goN2jQwKzd6oj0scceM6EPwx4ENW8T8QIEIACBShNAUAPQqWjdddddZjNS9erVK6TQoA8qZBpGUMXN1gdBtdUy1AsCEEgiAQQ1wKq6NqnB7DUQ\/auvvloWB1dHihqSUM+k6uXj8+fPD9xda4ujIKi2WIJ6QAACaSCAoGZYWSMS6SagatWqmU0\/GzZsqOAHulFIgz7oeqhuVNJNSzY+CKqNVqFOEIBAUgkgqBmW9UIPLl68OPRaNH1FoxN17tw5UmCHUjkPgloq8pQLAQikkQCCmmF178zomjVrzNnQsEejFJ111lmRQg+WyrEQ1FKRp1wIQCCNBBDUAKurWCoYDebw4osvVkjhBX7QgA9Dhw61dmMSgprGjzRthgAESkUg9YKqARv0rtE6deqU2UDD\/Ol0rm48+vTTT80NMxoZSZ+TTz7ZjEwPHTokGkD\/qaeesvZeUQS1VB8ryoUABNJIIPWC6q2Z1qtXL2\/7HzhwgDXUvKnxAgQgAIFkEki9oGrg+bZt25pr0PJ9dJfvunXrzOXjNj6MUG20CnWCAASSSiD1gppUw2q7ENQkW5e2QQACthFAULNY5Pzzzzfh\/vTcqa6r6rrpf\/7zHxPsYeHChbbZskJ9EFTrTUQFIQCBBBFAUAOMqRGRxo4dazYmBYUe1Ntm9Jyq3sxO6MEEfRpoCgQgAIEqEEBQA+BpgPrf\/\/73snfvXnN9m8bt1WhITZo0kcsuu8zsCm7YsCGhB6vgeLwKAQhAIGkEENQMi6poPvDAA3LssceaAPlBt8oQejBpHwPaAwEIQKDqBBDUDIbeMRq9QPyOO+4IJTx+\/Hhp3769mfbVtDY+rKHaaBXqBAEIJJUAghoiqMTyTarL0y4IQAAChSGAoGZwbdGihUyZMsVERho8eHBgFCSNrjR16lRzI81f\/vIX+e9\/\/1sY61QxV0aoVQTI6xCAAATyIICgBsDSa9u6du1qjsjMnDlT3nnnnbJUF110kfTt21datmwp\/\/rXv2TMmDF54C5uUgS1uLwpDQIQSDcBBDXA\/g0aNDB3op555plmFKoRkQ4fPmzOompEJR29erfR7Nmzx1oPQlCtNQ0VgwAEEkgAQQ0xqoYkvP76680xmUaNGpldvxpi8MsvvzTHaObOnWttyEGvSQhqAj+xNAkCELCWAIKaYZr69euLXt+2bds2M0q1NU5vFI9CUKNQIg0EIACBeAggqBkcO3bsaKIkrVy5MuuxmXjwFzYXBLWwfMkdAhCAgJ8AgprhD+3atRM9Y6q3yNx6661OewuC6rT5qDwEIOAYAQQ1wGBDhgyRbt26yYcffijPP\/+8iZZk8+ajMJ9DUB37NFJdCEDAaQIIaob5FIhGP9KNSLqrN9vDBeNO+z6VhwAEIBArAQQ1RFCPP\/74nKD3799v1ltXrFiRM20pEjBCLQV1yoQABNJKAEFNsOUR1AQbl6ZBAALWEUBQfSbRgA6tW7eWGjVqyBdffCEbN260zmD5VAhBzYcWaSEAAQhUjQCCKiJ6obhuROrSpYvUrl3bENVoSJs3b5bJkyfLsmXLqka5RG8jqCUCT7EQgEAqCSCoIuJdKK4jU71UfN++faIB8HVT0tatW2X48OFOjlYR1FR+pmk0BCBQIgKpF1SNjDRjxgxp2rSpPPzww\/Lkk08aU6ig6oajNm3ayOzZs2XWrFklMlHli0VQK8+ONyEAAQjkSyD1guoFcti1a5f07t1bjhw5UsbwuuuukwEDBsiSJUtkxIgR+bIteXoEteQmoAIQgECKCKReUDt16mRGojq126tXr3Km9\/62du1aczeqaw+C6prFqC8EIOAyAQQ1gqAGia0LRkdQXbASdYQABJJCAEFFUJPiy7QDAhCAQEkJIKgIakkdkMIhAAEIJIUAgvo\/QdVADlOnTi1n1+bNm5tNSTt27KjwN034zTffmFtpbL0zlSnfpHxMaQcEIOACAQT1f4Jar169vO1FcPy8kfECBCAAgcQSSL2gtm3bVgYOHCh169bN28g6Mp0+fboZpdr4MEK10SrUCQIQSCqB1AtqUg2r7UJQk2xd2gYBCNhGAEG1zSIx1gdBjREmWUEAAhDIQQBBTbCLIKgJNi5NgwAErCOAoFpnkvgqhKDGx5KcIAABCOQigKDmIuTw3xFUh41H1SEAAecIIKjOmSx6hRHU6KxICQEIQKCqBBDUqhK0+H0E1WLjUDUIQCBxBBDUxJn0hwYhqAk2Lk2DAASsI4CgWmeS+CqEoMbHkpwgAAEI5CKAoOYi5PDfEVSHjUfVIQAB5wggqM6ZLHqFEdTorEgJAQhAoKoEENSqErT4fQTVYuNQNQhAIHEEENTEmfSHBiGoCTYuTYMABKwjgKBaZ5L4KoSgxseSnCAAAQjkIoCg5iLk8N8RVIeNR9UhAAHnCCCozpkseoUR1OisSAkBCECgqgQQ1KoStPh9BNVi41A1CEAgcQQQ1MSZ9IcGIagJNi5NgwAErCOAoFpnkvgqhKDGx5KcIAABCOQigKDmIuTw3xFUh41H1SEAAecIIKjOmSx6hRHU6KxICQEIQKCqBBDUqhK0+H0E1WLjUDUIQCBxBBDUxJn0hwYhqAk2Lk2DAASsI4CgWmeS+CqEoMbHkpwgAAEI5CKAoOYi5PDfEVSHjUfVIQAB5wggqM6ZLHqFEdTorEgJAQhAoKoEENSqErT4fQTVYuNQNQhAIHEEENTEmfSHBiGoCTYuTYMABKwjgKBaZ5L4KoSgxseSnCAAAQjkIoCg5iLk8N8RVIeNR9UhAAHnCCCozpkseoUR1OisSAkBCECgqgQQ1KoStPh9BNVi41A1CEAgcQQQ1MSZ9IcGZRPUhx9+WFauXFmu9du3bxf94YEABCAAgfwJIKj5M3PmjWyCGtSIFStWyCuvvFJBVMOE9qSTThL9yXwQZmdchIpCAAIxEkBQY4RpW1bZBHXiCx\/Kjj0Hy6p89smN5Kb\/axPYhDChvfnmm0XLyHw0\/dixYxnt2uYQ1AcCECgoAQS1oHjjy\/yyyy6Tfv36SePGjeXbb7+VrVu3ykMPPSRvvfVWaCHZBHXY7Pdk1ebdZe+2a9lIJvX8peQjtPpyWPrMKWUXRq2MuOPzV3KCQBoJIKgOWL1bt25yyy23yHfffSdLly6VOnXqSIcOHeTgwYMybtw4effddwNbURlBzVdow9JnVujDtf+RlxbMtXY6WcV05MiRjLh6BeddAAAMu0lEQVQd+DxQRQjYSgBBtdUy\/6tXzZo1Zfr06XLKKafIxIkTZeHCheYv119\/vfTv31+WL18ut956a8EFNUw4owhwtunkMKHNNp0ctM4bZsagkXHQSNQT1LAR98CBA0WnsnkgAAEIhBFAUC33jXbt2sn48eNlx44d0rdvXzly5IipcZMmTeSBBx4QFdxhw4bJxo0bK7QkzhFqvoLqTx\/3dHI+Jstcz802EtV8w9rp6q7oqNPYmu7yyy8P3JSWD++kpYVLsEXhEswFQbW8B7jqqqtk8ODBsmTJEhkxYkS52k6dOlXOPPNMGT16dOC0r22CGmU0qw30RrT5po+ynptrJBp1Clvrme+u6DhcLUwgw\/KOunGslB1BPm0q9lp8nFyifrmJw08KnUecXApd12Lm7yqXaieccML3xQRVqrKuueYa0enG5557Tu6\/\/\/5y1ZgwYYKce+65Zkp43rx5oSPUJ95eL6s3Hd2A1LhBXRne\/efi\/12hf1+KMv1tCrJdvu1fuOq\/8rlvV3STBnXlknYtAt0iTGjj8KEwgcyWd1jd\/aNu74tG0Eg8jnpnyyOfNhWSbVAd4+QS1zJGoe0RJf84uUQpz5U0HhfXlohSI6g33nij9OnTRxYsWCDTpk3LS1DVuKMnz5J2JzdyxR+pJwQgAAGnCbh4bDA1glqVEap6ZT7TaU57MZWHAAQgYAGBYi9LxNHk1AhqVdZQ4wBNHhCAAAQgkGwCqRHUXLt8jznmGLPL97PPPku2xWkdBCAAAQgUhEBqBLUq51ALQp5MIQABCEAgUQRSI6hqNZ32HTRokHzzzTcVIiXde++9WcMPJsrqNAYCEIAABGInkCpBVXpdunSR3r175xXLN3bqZAgBCEAAAokjkDpBTZwFaRAEIAABCFhBAEG1wgxUAgIQgAAEXCeAoLpuQeoPAQhAAAJWEEBQs5ihMnenWmHVIlWiQYMGct9990mNGjWkV69eRSrVzmJ0F3nPnj3lyiuvlBNOOEGqVasme\/bsMZG5Zs+eXXYZg521L2yt\/vjHP8rVV18tP\/nJTwyHzZs3y8yZM2Xx4sWFLdih3PWOZo3mNn\/+\/AqR3BxqRpWr2qJFC5kyZYo0a9asQl7r16+3vp9BUENcoLJ3p1bZoxzJQCNHjRo1SvR874YNG6x39EJj1av\/VEz37t0ry5YtM8VpfOh69erJ888\/L5MnTy50FazMX69H\/POf\/2zuHNaLKerXr192BzE764+a7MILL5TbbrtNGjZsKHPmzEm1oHbq1EnGjh0rhw4dkp07d5bzaf0idvfdd1vp516lENQA83BmNdxnlU3Xrl2NgJ544okmoQvfHAv5KTz99NNl0qRJZvR1++23my8Y+px99tnyt7\/9zYxWNWiI9\/tC1sWmvL2rEX\/0ox\/JuHHj5J133jHVU9\/Rn\/fff1\/uuOMOm6pc9LroLI+OyPSeZp3pefrpp1MtqNddd50MGDAg8BKTohunEgUiqAHQckVVynZ3aiVs4NQr3jfIWrVqmRHHaaedJvv27Uv1CFWPYt1yyy2yatUqI5z+5+9\/\/7u0adNGRo4cac4+p+nRK7j0SsRt27aZTtJ7rrjiChk6dKgZyWdepZgmPtqP6BcN\/eL1+uuvi86KPfPMM6kW1CFDhkiPHj1Cb\/6y3T8Q1AALEfc33G07duxo7pXVa+4+\/vhjMzLbv39\/qgU1jJZOi+tdu8cdd5wZiangpvlRAbnooovkT3\/6k7lsQm990jXmtD46Ha5n4l999VXZsmWLuV4y7YKq\/Yl+wdAvW\/rlvW7duk7tRUBQAz7NVb2ZJi0dRKtWrRDULMb21lU\/+OAD0f9P8+PNbOia8tdff22+kP3jH\/9ILRIdvetaoa4LavS23\/3ud6kXVF1fnzFjhmi\/smvXLiOqOhOmvlO7dm0n9iIgqAEf6arcnZqmHgJBDbd237595Q9\/+IPpGO68887UrZ9mktFOsXPnzqLrqTrLkebNWt7ueBUQzze8L\/FpHqG2bt3aTIHrWrL\/M+MtHegFJroRUr+g2vogqIxQK+2bCGpFdDqtqeupuh62e\/duGT9+fNmu30qDTtiL3mYtFzrIQqDXjWuXXHKJzJo1S+bOnWuKQFCzk54wYYLZNf\/II4\/IE088UQizxJIngsoaaqUdCUEtj07Xe3QTzvnnny+bNm2SMWPGpH5kGuZculZ2zjnnOLv5pLIfGu8z07Rp09AsDh8+nDouHgz9DOk0r57h9j+6Wenaa6+1\/lgRghrg1rl2+XJ36lFoCOoPzqPTeLom1r59e1m5cqXZ1ZvZKVS2E3b1ve7du5v1wffee89M1fkf3aylnzP9b5o2Juk0r2561DOn\/kePoOkIbPXq1fLJJ5\/Im2++KR999JGrpq9Uvb1Rum7e042PLvoLghpges6hRvs8IKhHOXnHH3Rkqmct\/\/rXv6Y6MpLnPd4XU70u8a677jJioY8XyEDP7abxfG7Qp4spXxHvPLd+nvxBP9RfdJpcTxOo0G7fvj1aB1WCVAhqCHTuTs3tjQjqUUZeVC3dTKFTvd9++205eBolaPr06bJu3brcUBOWIjOClLdrU2d5HnroobI1xIQ1O+\/mIKhHkXn+8tVXX5nAH675C4KaxfW5OzV7v4CgHuWj05m\/\/e1vQ2EdOHAglYEdvNG7xjjWL6g6La6jUh1h\/POf\/5SXXnopb+FJ6gsI6g+zPUH+8thjj8lrr71mvfkRVOtNRAUhAAEIQMAFAgiqC1aijhCAAAQgYD0BBNV6E1FBCEAAAhBwgQCC6oKVqCMEIAABCFhPAEG13kRUEAIQgAAEXCCAoLpgJeoIAQhAAALWE0BQrTcRFYQABCAAARcIIKguWIk6QgACEICA9QQQVOtNRAXTQsB\/Z2iUNr\/88ssmdrBeiaaxg5cuXRrlNdJAAAIFIoCgFggs2UIgXwJt27Y1l0zrjRveo8HUmzVrJjt37jQ\/\/kcF9NJLL0VQ8wVNeggUiACCWiCwZAuBOAjobS033HCDLFq0SEaMGBFHluQBAQgUiACCWiCwZAuBOAggqHFQJA8IFIcAgloczpQCgUoRyCao3uUE\/jVUTX\/11VeLBhPv0KGDnHXWWVK7dm3R2zs0uPiDDz5obvS44IIL5LjjjjO\/f\/vtt2X8+PFlV87p9Vk33nij9OjRQ3784x9LtWrVzN2ur7\/+urm\/VAPc80AAAhUJIKh4BQQsJlBZQVWh1CvSdJ1Vr5U777zzTCt37NghjRo1kiVLlph\/60YoFdwnn3xSZs6cae521YvSO3fuLHrtnL5\/+PBhOeecc8x7ixcv5r5Xi\/2FqpWWAIJaWv6UDoGsBCojqLrm+uWXX8ro0aNl2bJlJn+9oLl79+6iV8lNnDhRFi5caH5\/0003yc033yxr166V\/v37l93tunfvXvPOhg0bTDq9em3KlCmio+JZs2bJU089heUgAIEMAggqLgEBiwlUVlBVSAcPHlzWMu++zc2bN0vv3r3Lpm1\/9atfyZgxY2TLli3Sq1cvmTBhghmdzp07V6ZNm1aOjCe+q1atKpe3xfioGgSKSgBBLSpuCoNAfgQqK6iZu4I9QVWhHTZsWFklvLOvW7duNYL6+OOPm1GoTgl\/8cUX5SrbsGFDI7aadsCAAaKjWB4IQOAHAggq3gABiwlUVlDnzJlTboTpCaoKpf\/4jV9QdaQ6adIkadq0aVYi27ZtM6K8ceNGi8lRNQgUnwCCWnzmlAiByASKKah9+vSRRx99VJo3by733XefaCQmHghAIDoBBDU6K1JCoOgEiimoOuWrx2I6duwYuoaqaT7++GPRevFAAALlCSCoeAQELCZQbEH1poZ3794to0aNko8++sjQ0XXVe+65x4RB1CM2ep6VBwIQQFDxAQg4Q6DYgqrnUMeNG2c2H+lZVv85VA3ysGbNGhk6dKgJ9MADAQggqPgABJwhUGxBVTCZkZKqV69uxPW9996TyZMnI6bOeA8VLTYBpnyLTZzyIAABCEAgkQQQ1ESalUZBAAIQgECxCSCoxSZOeRCAAAQgkEgCCGoizUqjIAABCECg2AQQ1GITpzwIQAACEEgkAQQ1kWalURCAAAQgUGwCCGqxiVMeBCAAAQgkkgCCmkiz0igIQAACECg2AQS12MQpDwIQgAAEEkkAQU2kWWkUBCAAAQgUmwCCWmzilAcBCEAAAokkgKAm0qw0CgIQgAAEik0AQS02ccqDAAQgAIFEEkBQE2lWGgUBCEAAAsUmgKAWmzjlQQACEIBAIgkgqIk0K42CAAQgAIFiE0BQi02c8iAAAQhAIJEEENREmpVGQQACEIBAsQkgqMUmTnkQgAAEIJBIAghqIs1KoyAAAQhAoNgE\/h8FhWds4HAblwAAAABJRU5ErkJggg==","height":0,"width":0}}
%---
%[output:075ecc54]
%   data: {"dataType":"image","outputData":{"dataUri":"data:,","height":0,"width":0}}
%---

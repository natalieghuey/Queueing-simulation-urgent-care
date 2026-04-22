# UrgentCare Simulation
A queueing simulation in Matlab.
Savannah Jellings and Natalie Huey.

This is an M/M/s queue simulation.
The overall architecture is event driven.

The main class is `ServiceQueue`.
It maintains a list of events, ordered by the time that they occur.
There is one `Arrival` scheduled at any time that represents the arrival of the next customer.
When a customer reaches the front of the waiting queue, they can be moved to a doctor.
Once a customer moves into a doctor, a `Departure` event for that customer is scheduled.
There should be one `Departure` event scheduled for each busy doctor.
If a customer becomes impatient and leaves before being served, they `Renege`.
When a customer reneges, they are removed from the queue and added to the renege list.
There is one `RecordToLog` scheduled at any time that represents the next time statistics will be added to the log table.
There is a document `Run_ServiceQueue_baseline` that simulates a queue without reneging.
There is a document `Run_ServiceQueueRenege` that simulates a queue with reneging.
The `ServiceQueueRenege` class handles a reneging event.

FYI: The use of "queueing" rather than "queuing" is for consistency with the textbook.

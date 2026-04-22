classdef Renege < Event
    % Renege Subclass of Event that represents the renege of a
    % Customer.

    properties
        % Customer - Index of the customer from which the
        % renege occurred
        Customer;
    end
    methods
        function obj = Renege(Time, customer)
            % Renege - Construct a renege event from a time and
            % customer index.
            arguments
                Time = 0.0;
                customer = 0;
            end
            
            % MATLAB-ism: This incantation is how to invoke the superclass
            % constructor.
            obj = obj@Event(Time);

            obj.Customer = customer;
        end
        function varargout = visit(obj, other)
            % visit - Call handle_renege

            % MATLAB-ism: This incantation means whatever is returned by
            % the call to handle_renege is returned by this visit
            % method.
            [varargout{1:nargout}] = handle_renege(other, obj);
        end
    end
end
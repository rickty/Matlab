% Package: Quandl
% Function: get
% Pulls data from the Quandl API.
% Inputs:
% Required:
% code - Quandl code of dataset wanted. String.
% Optional:
% start_date - Date of first data point wanted. String. 'yyyy-mm-dd'
% end_date - Date of last data point wanted. String. 'yyyy-mm-dd'
% transformation - Type of transformation applied to data. String. 'diff','rdiff','cumul','normalize'
% collapse - Change frequency of data. String. 'weekly','monthly','quarterly','annual'
% rows - Number of dates returned. Integer.
% type - Type of data to return. Leave blank for time series. 'raw' for a cell array.
% authcode - Authentication token used for continued API access. String.
% Returns:
% If type is blank or type = 'ts'
% timeseries - If only one time series in the dataset.
% tscollection - If more than one time series in the dataset.
% Type = 'fints'
% financial time series
% type = ASCII
% raw csv string
% type = data
% data matrx with date numbers

function [output headers] = get(code, varargin)
    % Parse input.
    p = inputParser;
    p.addRequired('code');
    p.addOptional('start_date',[]);
    p.addOptional('end_date',[]);
    p.addOptional('transformation',[]);
    p.addOptional('collapse',[]);
    p.addOptional('rows',[]);
    p.addOptional('type', []);
    p.addOptional('authcode',Quandl.auth());
    p.parse(code,varargin{:})
    start_date = p.Results.start_date;
    end_date = p.Results.end_date;
    transformation = p.Results.transformation;
    collapse = p.Results.collapse;
    rows = p.Results.rows;
    type = p.Results.type;
    authcode = p.Results.authcode;
    
    if strcmp(class(code), 'char') || (strcmp(class(code), 'cell') && prod(size(code)) == 1)
        if strcmp(class(code), 'cell')
            code = code{1};
        end
        code = regexprep(code, '\.', '/');
        if regexp(code, '.+\/.+\/.+')
            code = regexprep(code, '/', '.');
            string = strcat('http://www.quandl.com/api/v1/multisets.csv?columns=', code, '&sort_order=asc');
            % col = code(regexp(code, '(?<=\/)[^\/]+$'):end);
            % code = regexprep(code, '\/[^\/]+$', '');
            % string = strcat('http://www.quandl.com/api/v1/datasets/',code,'.csv?column=', col, '&sort_order=asc');
        else
            string = strcat('http://www.quandl.com/api/v1/datasets/',code,'.csv?sort_order=asc');
        end
    elseif strcmp(class(code), 'cell') 
        code = regexprep(code, '/', '.');
        for i = 2:length(code)
            code{i} = strcat(',', code{i});
        end
        string = strcat('http://www.quandl.com/api/v1/multisets.csv?columns=',[code{:}], '&sort_order=asc');
    end
    % string
    % Check for authetication token in inputs or in memory.
    if size(authcode) == 0
        'It would appear you arent using an authentication token. Please visit http://www.quandl.com/help/matlab or your usage may be limited.'
    else
        string = strcat(string, '&auth_token=',authcode);
    end
    % Adding API options.
    if size(start_date)
        string = strcat(string, '&trim_start=', datestr(start_date, 'yyyy-mm-dd'));
    end
    if size(end_date)
        string = strcat(string, '&trim_end=', datestr(end_date, 'yyyy-mm-dd'));
    end
    if size(transformation)
        string = strcat(string, '&transformation=',transformation);
    end
    if size(collapse)
        string = strcat(string, '&collapse=',collapse);
    end
    if size(rows)
        string = strcat(string, '&rows=',num2str(rows));
    end
    % Loading csv and checking if it exists.
    try
        csv = urlread(string);
    catch
        error('Quandl:code','Code does not exist.')
    end
    % Parsing input to be passed as a time series.
    csv = strread(csv,'%s','delimiter','\n');

    try
        headers = strread(csv{1},'%s','delimiter',',');
    catch exception
        error('Quandl returned an empty CSV file. (Invalid Code Likely)');
    end
    
    rowz = length(csv)-1;
    columns = length(headers);
    if columns > 101 && length(regexp(string,'multisets','match')) > 0
        'Maximum column length for multisets is 100 columns.'
        headers = headers(1:101);
    end

    for i = 1:rowz
        temp = textscan(csv{i+1}(12:end), '%f', 'Delimiter',',');
        temp = temp{1};
        temp = transpose(temp);
        if strcmp(csv{i+1}(end),',') %Matlab does not catch delimiters at end of line.
            temp = [temp, NaN];
        end
        if i == 1
            DATE = csv{i+1}(1:10);
        else
            DATE = char(DATE,csv{i+1}(1:10));
        end
        data(i,:) = temp;
    end
    DATE = cellstr(DATE);
    temp = size(type);
    % Creating time series from raw data.
    if temp(1) == 0 || strcmp(type, 'ts')
        ts = timeseries(data(:,1),DATE,'name',headers{2});
        if columns > 2
            output = tscollection({ts},'name',code);
            for i = 2:(columns-1)
                output = addts(output,data(:,i),headers{i+1});
            end
        else
            output = ts;
        end
    elseif strcmp(type, 'cellstr')
        output = [transpose(headers);DATE, num2cell(data)];
    elseif strcmp(type, 'ASCII')
        output = csv;
    elseif strcmp(type, 'fints')
        sanitized_headers = regexprep(regexprep(headers(2:end),' ','_'), '[^A-Z0-9a-z_]', '')
        output = fints(datenum(DATE), data, sanitized_headers);
    elseif strcmp(type, 'data')
        output = [datenum(DATE) data];
    else
        error('Invalid format');
    end
end
{   Routines for reading from a logica analyzer CSV file.
}
module csvana_read;
define csvana_read_file;
define csvana_read_rec;
%include 'csvana.ins.pas';
{
********************************************************************************
*
*   Subroutine CSVANA_READ_FILE (FNAM, MEM, ROOT_P, STAT)
*
*   Read the data from the logic analyzer CSV file FNAM.  The file name must end
*   in ".csv", but this may be omitted from FNAM.  ROOT_P will be returned
*   pointing to the new root data structure for the data from the CSV file.
*
*   MEM is the parent memory context.  A subordinate memory context will be
*   created, and all memory for the new data will be allocated under this
*   subordinate context.
*
*   When STAT is returned indicating error, no new memory context will be
*   created, no new memory allocated, and ROOT_P returned NIL.
}
procedure csvana_read_file (           {read logic analyzer CSV file, save data}
  in      fnam: univ string_var_arg_t; {name of CSV file to read, ".csv" suffix implied}
  in out  mem: util_mem_context_t;     {parent mem context, will create subordinate}
  out     root_p: csvana_root_p_t;     {returned pointer to CSV file data}
  out     stat: sys_err_t);            {returned completion status}
  val_param;

var
  cin: csv_in_t;                       {CSV file reading state}
  name: string_var32_t;                {field name}
  stat2: sys_err_t;                    {to avoid corrupting STAT}

label
  abort;

begin
  name.max := size_char(name.str);     {init local var string}
  root_p := nil;                       {init to not returning with data}

  csv_in_open (                        {open the CSV input file}
    fnam,                              {CSV file name}
    cin,                               {CSV file reading state}
    stat);
  if sys_error(stat) then return;

  csvana_root_new (mem, root_p);       {create root data structure, init to empty}
  string_copy (cin.conn.tnam, root_p^.tnam); {save full CSV file treename}
{
*   Read CSV file header line.
}
  csv_in_line (cin, stat);             {read the header line}
  if sys_error(stat) then goto abort;

  csv_in_field_str (cin, name, stat);  {read name of independent variable, not used}
  if sys_error(stat) then goto abort;

  while true do begin                  {read dependent value names until end of line}
    csv_in_field_str (cin, name, stat); {read name of this value}
    if string_eos(stat) then exit;     {hit end of line ?}
    if sys_error(stat) then goto abort; {hard error ?}
    csvana_field_new (root_p^, name);  {add new field to end of list}
    end;
{
*   Read each data line and create a new resulting record.
}
  while true do begin                  {back here each new data line}
    csvana_read_rec (cin, root_p^, stat); {read line, create new data record}
    if file_eof(stat) then exit;       {hit end of file ?}
    if sys_error(stat) then goto abort; {hard error ?}
    end;

  csv_in_close (cin, stat);            {close the CSV input file}
  if sys_error(stat) then goto abort;  {hard error ?}
  return;                              {normal return point, no error}

abort:                                 {error encountered with file open, STAT set}
  csv_in_close (cin, stat2);           {close the CSV file}
  csvana_root_del (root_p);            {deallocate CSV file data dynamic memory}
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_READ_REC (CIN, ROOT, STAT)
*
*   Read the next line from the CSV file open on CSVIN and add its data as a new
*   record to the CSV data at ROOT.
}
procedure csvana_read_rec (            {read line from CSV file, add as record}
  in out  cin: csv_in_t;               {CSV file reading stat}
  in out  root: csvana_root_t;         {root structure for data from this CSV file}
  out     stat: sys_err_t);            {returned completion status}
  val_param;

var
  rec_p: csvana_rec_p_t;               {pointer to new data record}
  tk: string_var80_t;                  {scratch token}
  time: sys_clock_t;                   {absolute time of this data record}
  fieldn: sys_int_machine_t;           {1-N dependent data field number}
  imax: sys_int_max_t;                 {integer field value}

begin
  tk.max := size_char(tk.str);         {init local var string}

  csv_in_line (cin, stat);             {read next CSV file line}
  if sys_error(stat) then return;

  csvana_rec_new (root, rec_p);        {create new record at end of data}
{
*   Handle the independent variable, which is the time of this record.
}
  csv_in_field_str (cin, tk, stat);    {get time field string into TK}
  if sys_error(stat) then return;

  string_t_csvana_t1 (tk, time, stat); {interpret absolute time string}
  if sys_error(stat) then return;

  if root.nrec = 1
    then begin                         {this is first record in data set}
      root.time0 := time;              {save absolute time of first record}
      rec_p^.time := 0.0;              {set relative time of this record}
      end
    else begin                         {not the first record}
      rec_p^.time := sys_clock_to_fp2 ( {save relative seconds from first record}
        sys_clock_sub (time, root.time0) );
      end
    ;
{
*   Read each dependent value and save it in the record.  Additional dta values
*   beyond those given names in the header line are ignored.  Missing data
*   values are set to default.
}
  for fieldn := 1 to root.nvals do begin {loop over the supported data values}
    csv_in_field_str (cin, tk, stat);  {get this field into TK}
    if string_eos(stat) then begin     {end of line is same as missing field}
      tk.len := 0;
      end;
    if sys_error(stat) then return;    {hard error ?}
    string_unpad (tk);                 {remove trailing spaces}

    if tk.len <= 0
      then begin                       {empty field, copy value from previous record}
        if rec_p^.prev_p = nil
          then begin                   {there is no previous record}
            rec_p^.data[fieldn] := 0;  {set to fixed default}
            end
          else begin                   {previous record exists}
            rec_p^.data[fieldn] := rec_p^.prev_p^.data[fieldn]; {copy from prev record}
            end
          ;
        end
      else begin                       {non-empty field string}
        string_t_int_max_base (        {interpret string as integer}
          tk,                          {string to interpret}
          10,                          {number base, decimal}
          [],                          {no special handling}
          imax,                        {returned integer value}
          stat);
        if sys_error(stat) then return;
        rec_p^.data[fieldn] := imax;   {save value of this field}
        end
      ;
    end;                               {back to do next field}
  end;

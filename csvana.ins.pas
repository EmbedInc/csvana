{   Private include file for the CSVANA program.
}
%include 'debug_switches.ins.pas';
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'stuff.ins.pas';
%include 'builddate.ins.pas';

type
  csvana_name_p_t = ^csvana_name_t;
  csvana_name_t = record               {name of one field}
    next_p: csvana_name_p_t;           {to next field name}
    name: string_var4_t;               {field name, allocated to actual name length}
    end;

  csvana_data_t =                      {dependent data values for one record}
    array[1..1] of int8u_t;

  csvana_rec_p_t = ^csvana_rec_t;
  csvana_rec_t = record                {one CSV file record}
    prev_p: csvana_rec_p_t;            {to previous record, NIL at first}
    next_p: csvana_rec_p_t;            {to next record, NIL at last}
    time: double;                      {seconds offset from first record}
    data: csvana_data_t;               {dependent data values this record}
    end;

  csvana_root_p_t = ^csvana_root_t;
  csvana_root_t = record               {root information about logic analyzer CSV file}
    mem_p: util_mem_context_p_t;       {context for all dynamic memory this CSV file}
    tnam: string_treename_t;           {full treename to source file, if any}
    nvals: sys_int_machine_t;          {number of dependent values in each record}
    name_p: csvana_name_p_t;           {to first name in list of field names}
    name_last_p: csvana_name_p_t;      {to last name in list of field names}
    time0: sys_clock_t;                {absolute time of first record}
    nrec: sys_int_machine_t;           {number of records in the list}
    rec_p: csvana_rec_p_t;             {to list of data records}
    rec_last_p: csvana_rec_p_t;        {to last record in list}
    end;

procedure csvana_field_new (           {add new field per record to CSV data}
  in out  root: csvana_root_t;         {CSV data to add field to}
  in      name: univ string_var_arg_t); {name of the new field}
  val_param; extern;

procedure csvana_read_file (           {read logic analyzer CSV file, save data}
  in      fnam: univ string_var_arg_t; {name of CSV file to read, ".csv" suffix implied}
  in out  mem: util_mem_context_t;     {parent mem context, will create subordinate}
  out     root_p: csvana_root_p_t;     {returned pointer to CSV file data}
  out     stat: sys_err_t);            {returned completion status}
  val_param; extern;

procedure csvana_read_rec (            {read line from CSV file, add as record}
  in out  cin: csv_in_t;               {CSV file reading stat}
  in out  root: csvana_root_t;         {root structure for data from this CSV file}
  out     stat: sys_err_t);            {returned completion status}
  val_param; extern;

procedure csvana_rec_new (             {alloc and init new CSV file data record}
  in out  root: csvana_root_t;         {CSV file data to add recrod to}
  out     rec_p: csvana_rec_p_t);      {to new record, will be last in CSV file data}
  val_param; extern;

procedure csvana_root_del (            {delete all data for a CSV file}
  in out  root_p: csvana_root_p_t);    {to root data structure, returned NIL}
  val_param; extern;

procedure csvana_root_new (            {allocate and init new root CSV file data}
  in out  mem: util_mem_context_t;     {parent mem context, will create subordinate}
  out     root_p: csvana_root_p_t);    {to returned initialized root data structure}
  val_param; extern;

{   Routines to allocate and init new memory structures.
}
module cavana_mem;
define csvana_root_new;
define csvana_root_del;
define csvana_rec_new;
define csvana_field_new;
%include 'csvana.ins.pas';
{
********************************************************************************
*
*   Subroutine CSVANA_ROOT_NEW (MEM, ROOT_P)
*
*   Create and initialize a new root data structure for one logic analyzer CSV
*   file info.  MEM is the parent memory context.  A subordinate memory context
*   will be created, and all dynamic memory for the new CSV file data will be
*   allocated under the subordinate context.  ROOT_P is returned pointing to the
*   newly allocated and initialized root data structure.
}
procedure csvana_root_new (            {allocate and init new root CSV file data}
  in out  mem: util_mem_context_t;     {parent mem context, will create subordinate}
  out     root_p: csvana_root_p_t);    {to returned initialized root data structure}
  val_param;

var
  mem_p: util_mem_context_p_t;         {to new private memory context}

begin
  util_mem_context_get (mem, mem_p);   {create our private memory context}

  util_mem_grab (                      {allocate root CSV file data structure}
    sizeof(root_p^), mem_p^, false, root_p);
  root_p^.mem_p := mem_p;              {save pointer to private mem context}
  root_p^.tnam.max := size_char(root_p^.tnam.str); {init CSV file name}
  root_p^.tnam.len := 0;
  root_p^.nvals := 0;                  {init number of dependent values per record}
  root_p^.name_p := nil;               {init list of field names}
  root_p^.name_last_p := nil;
  root_p^.time0 := sys_clock;          {init time of first record to arbitrary value}
  root_p^.nrec := 0;                   {init number of data records}
  root_p^.rec_p := nil;                {init pointer to list of records}
  root_p^.rec_last_p := nil;           {init pointer to last record}
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_ROOT_DEL (ROOT_P)
*
*   Deallocate all the dynamic memory of the CSV data pointed to by ROOT_P.  The
*   private memory context of the CSV data is also deleted.  ROOT_P is returned
*   NIL.
}
procedure csvana_root_del (            {delete all data for a CSV file}
  in out  root_p: csvana_root_p_t);    {to root data structure, returned NIL}
  val_param;

var
  mem_p: util_mem_context_p_t;         {to CSV data private memory context}

begin
  mem_p := root_p^.mem_p;              {save pointer to private memory context}

  util_mem_context_del (mem_p);        {delete mem context, dealloc all its mem}
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_REC_NEW (ROOT, REC_P)
*
*   Create a new initialized data record, and add it as the last record of the
*   CSV data ROOT.  The array of dependent values will be sized to the number of
*   dependent values listed in ROOT.
}
procedure csvana_rec_new (             {alloc and init new CSV file data record}
  in out  root: csvana_root_t;         {CSV file data to add recrod to}
  out     rec_p: csvana_rec_p_t);      {to new record, will be last in CSV file data}
  val_param;

var
  sz: sys_int_adr_t;                   {size of data record descriptor to allocate}
  ii: sys_int_machine_t;               {scratch integer and loop counter}

begin
  sz := offset(rec_p^.data);           {init size to all but the data array}
  sz := sz + (sizeof(rec_p^.data[1]) * root.nvals); {add size required for data array}
  util_mem_grab (                      {allocate descriptor for the data record}
    sz, root.mem_p^, false, rec_p);

  rec_p^.prev_p := root.rec_last_p;    {point to previous record}
  rec_p^.next_p := nil;                {init to no subsequent record}
  rec_p^.time := 0.0;                  {init time relative to first record}
  for ii := 1 to root.nvals do begin   {init each data value}
    rec_p^.data[ii] := 0;
    end;

  if root.rec_last_p = nil
    then begin                         {this is first record in list}
      root.rec_p := rec_p;             {set pointer to first record}
      end
    else begin                         {adding to end of existing list}
      root.rec_last_p^.next_p := rec_p; {set formward pointer in previous record}
      end
    ;
  root.rec_last_p := rec_p;            {update pointer to last record in list}
  root.nrec := root.nrec + 1;          {count one more record in the list}
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_FIELD_NEW (ROOT, NAME)
*
*   Add a new dependent field to the CSV file data at ROOT.  NAME is the name of
*   the new field.  It will be added to the end of the existing list of fields.
*
*   All fields should be added before any data records are created.  The data
*   array of data records is sized according to the number of fields defined at
*   the time the record is created.
}
procedure csvana_field_new (           {add new field per record to CSV data}
  in out  root: csvana_root_t;         {CSV data to add field to}
  in      name: univ string_var_arg_t); {name of the new field}
  val_param;

var
  name_p: csvana_name_p_t;             {pointer to new field name descriptor}

begin
  util_mem_grab (                      {allocate memory for field name descriptor}
    offset(name_p^.name) + string_size(name.len), {amount of memory to allocate}
    root.mem_p^,                       {memory context to allocate under}
    false,                             {don't need to individually deallocate this mem}
    name_p);                           {returned pointer to the new memory}

  name_p^.next_p := nil;               {init to no following field}
  name_p^.name.max := name.len;        {save the name of this field}
  string_copy (name, name_p^.name);

  if root.name_last_p = nil
    then begin                         {this is first name in list}
      root.name_p := name_p;
      end
    else begin                         {adding to end of existing list}
      root.name_last_p^.next_p := name_p; {set forward link in previous entry}
      end
    ;
  root.name_last_p := name_p;          {update pointer to last name list entry}

  root.nvals := root.nvals + 1;        {count one more dependent value}
  end;

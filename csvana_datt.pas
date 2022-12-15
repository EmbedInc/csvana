{   Data time values manipulation.
}
module csvana_datt;
define csvana_datt_upd;
define csvana_zoom;
%include 'csvana.ins.pas';
{
********************************************************************************
*
*   Subroutine CSVANA_DATT_UPD
*
*   Sanitize and update the data range control state.  The following values are
*   sanitized:
*
*     DATT1, DATT2
*
*       Data range to display.  Clipped to the available data range.
*
*     MEAS1, MEAS2
*
*       Start and end of the measurement interval.  These are clipped to the
*       data range.  MEAS1 is guaranteed to be less than MEAS2, and a small
*       minimum interval between the two is guaranteed.
*
*     CURS
*
*       Data value of the data cursor.  This is clipped to the displayed data
*       range.
*
*   The following values are re-computed:
*
*     DATDT
*
*       Size of data range to display (DATT2 - DATT1).
}
procedure csvana_datt_upd;             {sanitize and update data range control state}
  val_param;

var
  d: double;                           {min meas interval size}

begin
  d := 1.0e-35;                        {min data delta}
  datt1 := max(datt1, csv_p^.rec_p^.time); {clip display range to data range}
  datt2 := max(datt2, datt1 + d);
  datt2 := min(datt2, csv_p^.rec_last_p^.time);
  datt1 := min(datt1, datt2 - d);

  datdt := datt2 - datt1;              {save displayed data range size}
  d := datdt * minmeas;                {make min meas interval size}

  meas1 := max(meas1, datt1);          {clip measurement interval to display range}
  meas2 := max(meas2, meas1 + d);
  meas2 := min(meas2, datt2);
  meas1 := min(meas1, meas2 - d);

  curs := min(datt2, max(datt1, curs)); {clip cursor to displayed range}
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_ZOOM (ZIN)
*
*   Zoom in ZIN standard increments.  ZIN can be negative to cause zooming out.
*
*   The draw area is scaled around the data cursor.  Only the display mapping
*   state is updated.  The display is not redrawn.
}
procedure csvana_zoom (                {zoom in/out}
  in      zin: sys_int_machine_t);     {increments to zoom in, negative for zoom out}
  val_param;

var
  zf: real;                            {zoom factor, rel size of new data width}

begin
  if zin = 0 then return;              {nothing to do ?}

  zf := zoomf ** (-zin);               {make zoom scale factor}

  datt1 := (datt1 - curs) * zf + curs; {zoom about the cursor}
  datt2 := (datt2 - curs) * zf + curs;
  csvana_datt_upd;                     {sanitize the result}
  end;

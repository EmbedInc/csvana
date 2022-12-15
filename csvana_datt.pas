{   Data time values manipulation.
}
module csvana_datt;
define csvana_datt_upd;
%include 'csvana.ins.pas';
{
********************************************************************************
*
*   Subroutine CSVANA_DATT_UPD
*
*   Sanitize and update the data range control state.  The following values are
*   taken as input:
*
*     DATT1, DATT2
*
*       Data range to display.
*
*   The following values are sanitized to the data range:
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
  datdt := datt2 - datt1;              {save displayed data range size}
  d := datdt * minmeas;                {make min meas interval size}

  meas1 := max(meas1, datt1);          {clip measurement interval to data range}
  meas2 := max(meas2, meas1 + d);
  meas2 := min(meas2, datt2);
  meas1 := min(meas1, meas2 - d);

  curs := min(datt2, max(datt1, curs)); {clip cursor to displayed range}
  end;

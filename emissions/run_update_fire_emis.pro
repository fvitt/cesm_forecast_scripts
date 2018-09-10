pro run_update_fire_emis

yr = 2017
mon = 7
day1=1
day2=31

for mon=9,9 do begin
 day1=26
 if (mon eq 9) then day2=28 else day2=31

 for day=day1,day2 do begin

  date = yr*10000L + mon*100L + day
  print,'*******'
  print,date
  update_fire_emis_fcst,date

 endfor
endfor
end

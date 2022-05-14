/*****Import and merge datasets*****/
*Import datasets;
proc import OUT=cycles DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload DSMC 2019.xls" DBMS=xls REPLACE; SHEET="Followup"; GETNAMES=YES; run;
proc import OUT=treatment DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload06049_2017Mar22.xls" DBMS=xls REPLACE; SHEET="Master"; GETNAMES=YES; run;
proc import OUT=denice DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\Data_from_Denice.xls" DBMS=xls REPLACE; GETNAMES=YES; run;

*Merge datasets;
data treatment;
	set treatment (keep=Consortium_ID Off_Treatment_Reason Sex);
	if Off_treatment_Reason="" then delete;
run;

data cycles;
	set cycles (keep=Consortium_ID Number_Courses);
run;

proc sort data=treatment; by Consortium_ID; run;
proc sort data=cycles; by Consortium_ID; run;
data combined;
	merge treatment cycles;
	by Consortium_ID;

	if Consortium_ID="COH-126" then Sex="Male";
	if Consortium_ID="USC-116" then Sex="Female";
run;

*Eliminate non-1.4 dose subjects;
proc sort data=denice; by Consortium_ID; run;
proc sort data=combined; by Consortium_ID; run;
data combined;
	merge combined (in=in1) denice (keep=Consortium_ID in=in2);
	by Consortium_ID;
	if in1 and in2;

	*Flag if more than 2 cycles received;
	if Number_Courses >1 then multi_course=1;
	else multi_course=0;
run;


/*****Summary of Treatment*****/
*Number of cycles received;
proc sort data=combined; by Sex; run;
proc means data=combined mean std min max P25 P50 P75; 
	by Sex;
	var Number_Courses;
run;

*Wilcoxon test for number of cycles received;
proc npar1way wilcoxon correct=no data=combined;
	class Sex;
	var Number_Courses;
run;

*Number who received more than 2 cycles;
proc freq data=combined;
	tables multi_course*Sex;
run;

*Reason off treatment;
proc freq data=combined;
	tables Off_Treatment_Reason*Sex;
run;

proc print data=combined; run;

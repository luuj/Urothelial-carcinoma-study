/*****Import and merge datasets*****/
*Import master dataset;
proc import OUT=master DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload06049_2017Mar22.xls" DBMS=xls REPLACE; SHEET="Master"; GETNAMES=YES; run;

*Import OnStudy dataset;
proc import OUT=onstudy DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload DSMC 2019.xls" DBMS=xls REPLACE; SHEET="OnStudy"; GETNAMES=YES; run;

*Import toxicity dataset;
proc import OUT=toxicity DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload DSMC 2019.xls" DBMS=xls REPLACE; SHEET="Toxicities"; GETNAMES=YES; run;

*Import radiation dataset;
proc import OUT=radiation DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload DSMC 2019.xls" DBMS=xls REPLACE; SHEET="PrRad"; GETNAMES=YES; run;

*Import creatinine dataset;
proc import OUT=creatinine DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\Baseline SerumCreat data for Eisai - 2-29-2016.xls" DBMS=xls REPLACE; SHEET="Baseline Creatinine Data"; GETNAMES=YES; run;

*Import Denice's dataset;
proc import OUT=denice DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\Data_from_Denice.xls" DBMS=xls REPLACE; GETNAMES=YES; run;

*Merge master and onstudy datasets;
data onstudy;
	set onstudy(keep=Consortium_ID Performance_status stage_at_dx);
run;

proc sort data=onstudy; by Consortium_ID; run;
proc sort data=master; by Consortium_ID; run;
data master;
	merge master onstudy;
	by Consortium_ID;
run;

*Remove non-1.4mg dose patients;
proc sort data=denice; by Consortium_ID; run;
proc sort data=master; by Consortium_ID; run;
data master;
	merge master (in=in1) denice (keep=Consortium_ID in=in2);
	by Consortium_ID;
	if in1 and in2;
run;




/*****Master dataset*****/
*Clean the master dataset and add appropriate variables;
data master;
	set master(keep=Consortium_ID Sex Race Ethnicity Date_of_birth On_Study_Date
			   Dx_Site Dx_Histology Performance_status stage_at_dx);

	*Delete missing IDs;
	if Consortium_ID="Missing" OR Consortium_ID="" then delete;

	*Clean up race variable;
	if Race="Y" then Race="Other";
	if Race="Caucasian" AND Ethnicity^="Non-Hispanic" then Race="Hispanic";

	*Calculate discrete age;
	Age=floor((On_Study_Date-Date_of_birth)/365);

	*Combine primary site variables;
	if Dx_Site="Bladder, NOS" OR Dx_Site="Lateral wall of bladder" OR Dx_Site="Trigone of bladder" then Dx_Site="Bladder";
	if Dx_Site="Kidney, NOS" then Dx_Site="Kidney";
	if Dx_Site="Ureter" OR Dx_Site="Ureteric orifice" then Dx_Site="Ureter";

	*Combine histology variables;
	if Dx_Histology="Adenocarcinoma, NOS" then Dx_Histology="Adenocarcinoma";
	if Dx_Histology="Carcinoma, NOS" OR Dx_Histology="Neoplasm, malignant" OR Dx_Histology="Not Otherwise Specified" then Dx_Histology="NOS";
	if Dx_Histology="Papillary carcinoma in situ" OR Dx_Histology="Papillary carcinoma, NOS" then Dx_Histology="Papillary carcinoma";
	if Dx_Histology="Papillary trans. cell carcinoma" OR Dx_Histology="Papillary trans. cell carcinoma, non-invasive" then Dx_Histology="Papillary trans. cell carcinoma";
	if Dx_Histology="Squamous cell carcinoma, NOS" then Dx_Histology="Squamous cell carcinoma";
	if Dx_Histology="Transitional cell carcinoma in situ" OR Dx_Histology="Transitional cell carcinoma, NOS" then Dx_Histology="Transitional cell carcinoma";

	*Clean up stage_at_dx variable;
	if stage_at_dx="-9" OR stage_at_dx="0A" OR stage_at_dx="TIS" then stage_at_dx="Unknown";
run;




/*****Baseline dataset*****/
data baseline;
	set toxicity (keep=Consortium_ID Course_Number MedDRA_LLT___CTEP_Term Grade);
	
	if Course_Number NE "0" then delete;
	if MedDRA_LLT___CTEP_Term NE "Peripheral sensory neuropathy" AND MedDRA_LLT___CTEP_Term NE "Hearing loss" then delete;
run;

*Merge baseline with master to get gender for each subject;
proc sort data=baseline; by Consortium_ID; run;
proc sort data=master; by Consortium_ID; run;
data baseline;
	merge baseline (in=inbaseline) master (in=inmaster);
	by Consortium_ID;
	if inbaseline and inmaster;
run;




/*****Denice's dataset*****/
data denice;
	set denice;

	*Combine prior cystectomy outcomes;
	if Prior_cyctectomy="no" then Prior_cyctectomy="No";
	if Prior_cyctectomy="yes" then Prior_cyctectomy="Yes";

	*Combine platins for primary outcomes;
	if Platins_for_Primary="NONE" then Platins_for_Primary="none";

	*Categorical platins for primary;
	if Platins_for_Primary="none" then Platins_for_Primary_cat=0;
	else Platins_for_Primary_cat=1;

	*Categorical taxanes and tubulin for primary;
	if Taxanes_for_primary="TAXOL" or Taxanes_for_primary="TAXOTERE" or Tubulin_for_primary="yes" then Taxanes_or_tubulin=1;
	else Taxanes_or_tubulin=0;

	*Categorical taxanes and tubulin for advanced disease;
	if Taxanes_for_adv_dz="TAXOTERE" or Taxanes_for_adv_dz="TAXOL + TAXOTERE" or Taxanes_for_adv_dz="TAXOL" or Tubulin_for_adv_dz="yes" then TT_adv=1;
	else TT_adv=0;

	if treatadvdz=0 then prior_treat_tax=0;
	else if Taxanes_for_adv_dz="TAXOTERE" or Taxanes_for_adv_dz="TAXOL + TAXOTERE" or Taxanes_for_adv_dz="TAXOL" then prior_treat_tax=2;
	else prior_treat_tax=1;
run;



/*****Radiation dataset*****/
data radiation;
	set radiation(keep=Consortium_ID Prior_Rad_Reason);

	*Only keep primary radiation;
	if Prior_Rad_Reason NE "Primary" then delete;
run;

*Merge radiation with master to get gender for each subject;
proc sort data=radiation; by Consortium_ID; run;
proc sort data=master; by Consortium_ID; run;
data radiation;
	merge radiation (in=inradiation) master (in=inmaster);
	by Consortium_ID;
	if inradiation and inmaster;
run;




/*****Creatinine dataset*****/
data creatinine;
	set creatinine;

	*Calculate creatinine clearance;
	calc_creatinine = ((140 - Baseline_age__Yrs_) / (Baseline_Serum_Creatinine)) * (Baseline_wt__kg_ / 72);

	*Adjust for females;
	if Sex="Female" then calc_creatinine=calc_creatinine*0.85;
run;




/*****Table 1 Descriptive Results*****/
*Age;
proc sort data=master; by Sex; run;
proc means data=master min max median P25 P75;
	by Sex;
	var age;
run;

*Race;
proc freq data=master;
	table Race*Sex;
run;

*Primary site;
proc freq data=master;
	table Dx_Site*Sex;
run;

*Histology;
proc freq data=master;
	table Dx_Histology*Sex;
run;

*Performance status;
proc freq data=master;
	table performance_status*Sex;
run;

*Stage at Dx;
proc freq data=master;
	table stage_at_dx*Sex;
run;

*Baseline hearing loss and neuropathy;
proc sort data=baseline; by Sex; run;
proc freq data=baseline; 
	by Sex;
	table MedDRA_LLT___CTEP_Term*Grade;
run;

*Baseline serum creatinine and CRCL;
proc sort data=creatinine; by Sex; run;
proc means data=creatinine mean std min max median P25 P75;
	by Sex;
	var calc_creatinine baseline_CRCL;
run;

*Prior cystectomy;
proc freq data=denice; 
	table Prior_cyctectomy*Sex; 
run;

*Prior radiation;
proc freq data=radiation;
	table Prior_Rad_Reason*Sex;
run;

*Platins for primary - categorized into yes and no;
proc freq data=denice;
	table Platins_for_Primary_cat*Sex;
run;

*Taxanes or tubulin for primary - categorized into yes and no;
proc freq data=denice;
	tables Taxanes_or_tubulin*Sex;
run;

*Number of patients who got treatment for advance disease;
proc freq data=denice;
	tables treatadvdz*Sex;
run;

*For those with advanced disease, how many got platins;
proc freq data=denice;
	where treatadvdz=1;
	tables Platins_for_adv_dz*Sex;
run;

*For those with advanced disease, how many got taxanes or tubulin;
proc freq data=denice;
	where treatadvdz=1;
	tables TT_adv;
run;

*Prior treatment - no taxanes vs taxanes;
proc freq data=denice;
	where treatadvdz=1;
	tables Taxanes_for_adv_dz*Sex;
run;




/*****Table 1 hypothesis testing*****/
*Age;
proc npar1way wilcoxon correct=no data=master;
	class Sex;
	var age;
run;

*CRCL;
proc npar1way wilcoxon correct=no data=creatinine;
	class Sex;
	var calc_creatinine;
run;

*Race;
proc freq data=master;
	tables Sex*Race / expected chisq;
run;

*Performance status;
proc freq data=master;
	tables Sex*performance_status / expected chisq;
run;

*Cystectomy;
proc freq data=denice; 
	table Prior_cyctectomy*Sex / expected chisq; 
run;

*Prior treatment;
proc freq data=denice;
	table prior_treat_tax*Sex / expected chisq;
run;

*Renal group;
proc freq data=denice;
	table renalfunction*Sex / expected chisq;
run;

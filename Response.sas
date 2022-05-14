/*****Import datasets*****/
proc import OUT=master DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload06049_2017Mar22.xls" DBMS=xls REPLACE; SHEET="Master"; GETNAMES=YES; run;
proc import OUT=followup DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload DSMC 2019.xls" DBMS=xls REPLACE; SHEET="Followup"; GETNAMES=YES; run;
proc import OUT=denice DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\Data_from_Denice.xls" DBMS=xls REPLACE; GETNAMES=YES; run;
proc import OUT=OnStudy DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload DSMC 2019.xls" DBMS=xls REPLACE; SHEET="OnStudy"; GETNAMES=YES; run;
proc import OUT=creatinine DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\Baseline SerumCreat data for Eisai - 2-29-2016.xls" DBMS=xls REPLACE; SHEET="Baseline Creatinine Data"; GETNAMES=YES; run;



/********************START - RUN ALL THE CODE IN THIS BLOCK TO CREATE THE USEABLE DATASET - START********************/
/*****Retrieve variables from datasets*****/
*Performance status;
data OnStudy;
	set OnStudy (keep=Consortium_ID Performance_status);

	*Categorize performance status;
	if Performance_status=100 or Performance_status=90 then Performance_cat=1;
	else Performance_cat=0;

	*Continuous performance status;
	Performance_cont=input(Performance_status, BEST3.);
run;

*Sex, age, race;
data master;
	set master (keep=Consortium_ID Sex On_Study_Date Date_of_birth Race);
	if Consortium_ID="Missing" or Consortium_ID="" or Consortium_ID="CHI-086" or Consortium_ID="USC-020" then delete;

	*Calculate discrete age;
	Age_Cont=floor((On_Study_Date-Date_of_birth)/365);

	*Categorize age into quartiles;
	if Age_Cont >=75 then Age_Cat=3;
	else if Age_Cont >=68 then Age_Cat=2;
	else if Age_Cont >=57 then Age_Cat=1;
	else Age_Cat=0;

	*Categorize race into white vs. non-white;
	if Race="Caucasian" then White=1;
	else White=0;
run;

*CRCL;
data creatinine;
	set creatinine;

	*Calculate creatinine clearance;
	calc_creatinine = ((140 - Baseline_age__Yrs_) / (Baseline_Serum_Creatinine)) * (Baseline_wt__kg_ / 72);

	*Adjust for females;
	if Sex="Female" then calc_creatinine=calc_creatinine*0.85;

	*Categorize CRCL into quartiles;
	if calc_creatinine > 82 then calc_cat=3;
	else if calc_creatinine >59 then calc_cat=2;
	else if calc_creatinine >43 then calc_cat=1;
	else calc_cat=0;
run;

*Renal function, prior cystectomy, prior treatment groups;
data denice;
	set denice;

	*Combine prior cystectomy outcomes;
	if Prior_cyctectomy="no" then Prior_cyctectomy="No";
	if Prior_cyctectomy="yes" or Prior_cyctectomy="Partial" then Prior_cyctectomy="Yes";

	*Categorize three prior treatment groups;
	if treatadvdz=0 then prior_treat_tax=0;
	else if Taxanes_for_adv_dz="TAXOTERE" or Taxanes_for_adv_dz="TAXOL + TAXOTERE" or Taxanes_for_adv_dz="TAXOL" then prior_treat_tax=2;
	else prior_treat_tax=1;
run;

*Best response;
data followup;
	set followup (keep=Consortium_ID Best_Response);
run;




/*****Merge datasets*****/
proc sort data=OnStudy; by Consortium_ID; run;
proc sort data=FollowUp; by Consortium_ID; run;
proc sort data=master; by Consortium_ID; run;
proc sort data=denice; by Consortium_ID; run;
proc sort data=creatinine; by Consortium_ID; run;
data combined;
	merge OnStudy FollowUp master denice creatinine;
	by Consortium_ID;

	if Consortium_ID = "" or Consortium_ID="Missing" then delete;
run;

*Remove non-1.4mg dose patients;
proc sort data=denice; by Consortium_ID; run;
proc sort data=combined; by Consortium_ID; run;
data combined;
	merge combined (in=in1) denice (keep=Consortium_ID in=in2);
	by Consortium_ID;
	if in1 and in2;
run;

*Categorical formats;
proc format;
	value age_fmt 0="25-56.9" 1="57-67.9" 2="68-74.9" 3="75-90";
	value race_fmt 0="Non-White" 1="White";
	value perf_fmt 0="80-60" 1="100-90";
	value crcl_fmt 0="19-42.9" 1="43-58.9" 2="59-81.9" 3="82-218";
	value trt_fmt 0="No prior treatment for advanced disease" 1="No taxanes for advanced disease" 2="Taxanes for advanced disease";
run;




/*****Update combined dataset*****/
data combined;
	set combined (keep=Consortium_ID Sex Age_Cont Age_Cat White Performance_cat Performance_cont calc_cat calc_creatinine renalfunction
					   Prior_cyctectomy prior_treat_tax Best_Response);

	*Set individual responses;
	if Consortium_ID="USC-016" or
	   Consortium_ID="USC-022" or 
	   Consortium_ID="USC-037" or
	   Consortium_ID="UCD-057" or
	   Consortium_ID="USC-059" or
	   Consortium_ID="CHI-099" or
	   Consortium_ID="USC-136" or
	   Consortium_ID="USC-147" or
	   Consortium_ID="USC-154" or
	   Consortium_ID="USC-156" then Best_Response="N/A";

	if Consortium_ID="CHI-089" then Best_Response="Progressive Disease";

	*Update partial responses - if more than two partial PRs, then confirmed PR. Else, SD.;
	if Consortium_ID="CHI-062" or Consortium_ID="USC-170" then Best_Response="Stable Disease";

	*Update response names;
	if Best_Response="Complete (CR)" or Best_Response="NED" then Best_Response="Confirmed CR";
	if Best_Response="Unconfirmed PR" then Best_Response="Stable Disease";
	if Best_Response="Progression" then Best_Response="Progressive Disease";
	if Best_Response="Continuing PR" then Best_Response="Confirmed PR";
	if Best_Response="Partial (PR)" then Best_Response="Confirmed PR";

	*Logistic regression dependent variable;
	if Best_Response="Confirmed CR" or Best_Response="Confirmed PR" then overall_best_response=1;
	else overall_best_response=2;

	*Format categorical variables;
	format Age_Cat age_fmt. calc_cat crcl_fmt. prior_treat_tax trt_fmt. White race_fmt. Performance_cat perf_fmt.;
run;
/********************END - RUN ALL THE CODE IN THIS BLOCK TO CREATE THE USEABLE DATASET - END ********************/








/*****Response Table*****/
proc freq data=combined; 
	tables Best_Response*Sex; 
run;

data check12weeks;
	set combined;
	where Best_Response="Stable Disease";
	keep Consortium_ID;
run;




/*****Univariate logistic regression*****/
%macro logReg(catVar, refName);
proc logistic data=combined;
	class &catVar(ref=&refName);
	model overall_best_response = &catVar;
run;
%mend logReg;

%logReg(Sex, "Male");
%logReg(Age_cat, "25-56.9");
%logReg(White, "White");
%logReg(performance_cat, "100-90");
%logReg(renalfunction, "Normal Renal function");
%logReg(calc_cat, "19-42.9");
%logReg(prior_treat_tax, "No prior treatment for advanced disease");

proc freq data=combined;
	tables performance_cat*Age_cat*overall_best_response / chisq;
run;


/*****Multivariate logistic regression*****/
*Stepwise;
proc logistic data=combined;
	class Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax; 
	model overall_best_response = Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax  /
		  selection=stepwise slentry=0.20 slstay=0.20;
run;

*Backward;
proc logistic data=combined;
	class Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax; 
	model overall_best_response = Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax  /
		  selection=backward slentry=0.20 slstay=0.20;
run;

*Forward;
proc logistic data=combined;
	class Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax; 
	model overall_best_response = Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax  /
		  selection=forward slentry=0.20 slstay=0.20;
run;

*Manual;
proc logistic data=combined;
	class Sex (ref="Male") Age_Cat (ref="25-56.9") Performance_Cat (ref="100-90") prior_treat_tax (ref="No prior treatment for advanced disease");
	model overall_best_response = Sex Age_Cat Performance_Cat prior_treat_tax;
run; 




/*****Number of responders by number of patients*****/
%macro eventCounter(catVar);
proc freq data=combined;
	tables &catVar*overall_best_response;
run;
%mend eventCounter;

%eventCounter(age_cat);
%eventCounter(white);
%eventCounter(performance_cat);
%eventCounter(renalfunction);
%eventCounter(calc_cat);
%eventCounter(prior_treat_tax);
%eventCounter(sex);

/*****Import datasets*****/
proc import OUT=OnStudy DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload DSMC 2019.xls" DBMS=xls REPLACE; SHEET="OnStudy"; GETNAMES=YES; run;
proc import OUT=FollowUp DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload DSMC 2019.xls" DBMS=xls REPLACE; SHEET="Followup"; GETNAMES=YES; run;
proc import OUT=Drug DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload DSMC 2019.xls" DBMS=xls REPLACE; SHEET="Drug"; GETNAMES=YES; run;
proc import OUT=Master DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload06049_2017Mar22.xls" DBMS=xls REPLACE; SHEET="Master"; GETNAMES=YES; run;
proc import OUT=denice DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\Data_from_Denice.xls" DBMS=xls REPLACE; GETNAMES=YES; run;
proc import OUT=creatinine DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\Baseline SerumCreat data for Eisai - 2-29-2016.xls" DBMS=xls REPLACE; SHEET="Baseline Creatinine Data"; GETNAMES=YES; run;




/********************START - RUN ALL THE CODE IN THIS BLOCK TO CREATE THE USEABLE DATASET - START********************/
/*****Obtain variables from datasets*****/
*Start of treatment, performance status;
data OnStudy;
	set OnStudy (keep=Consortium_ID Treatment_Start_Date Performance_status);

	*Format date variable;
	TreatmentStartDate=input(Treatment_Start_Date, anydtdte32.);
	format TreatmentStartDate mmddyy8.;

	*Categorize performance status;
	if Performance_status=100 or Performance_status=90 then Performance_cat=1;
	else Performance_cat=0;

	*Continuous performance status;
	Performance_cont=input(Performance_status, BEST3.);
run;

*Progression, progression date, and death date;
data FollowUp;
	set FollowUp (keep=Consortium_ID Progression Progression_Date Date_of_Death);

	*Format date variable;
	ProgressionDate=input(Progression_Date, anydtdte32.);
	DeathDate=input(Date_of_Death, anydtdte32.);
	format ProgressionDate  DeathDate mmddyy8.;
	drop Progression_Date Date_of_Death;
run;

*Last follow up;
data Drug; 
	set Drug; 
	if Assessment_Date="" or Assessment_date="." then delete; 

	*Format date variable;
	AssessmentDate=input(Assessment_Date, anydtdte32.);
	format AssessmentDate mmddyy8.;
	drop Assessment_Date;
run;

proc sort data=Drug; by Consortium_ID DESCENDING AssessmentDate; run;
proc sort data=Drug nodupkey; by Consortium_ID; run;
data Drug;
	set Drug (keep=Consortium_ID AssessmentDate);
run;

*Sex, age, race;
data Master;
	set Master (keep=Consortium_ID Sex On_Study_Date Date_of_birth Race);
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




/*****Merge main dataset*****/
*Categorical formats;
proc format;
	value age_fmt 0="25-56.9" 1="57-67.9" 2="68-74.9" 3="75-90";
	value race_fmt 0="Non-White" 1="White";
	value perf_fmt 0="80-60" 1="100-90";
	value crcl_fmt 0="19-42.9" 1="43-58.9" 2="59-81.9" 3="82-218";
	value trt_fmt 0="No prior treatment for advanced disease" 1="No taxanes for advanced disease" 2="Taxanes for advanced disease";
run;

proc sort data=OnStudy; by Consortium_ID; run;
proc sort data=FollowUp; by Consortium_ID; run;
proc sort data=Drug; by Consortium_ID; run;
proc sort data=Master; by Consortium_ID; run;
proc sort data=denice; by Consortium_ID; run;
proc sort data=creatinine; by Consortium_ID; run;
data combined;
	merge OnStudy FollowUp Drug Master denice creatinine;
	by Consortium_ID;

	if Consortium_ID="" then delete;
run;

*Remove non-1.4mg dose patients;
proc sort data=denice; by Consortium_ID; run;
proc sort data=combined; by Consortium_ID; run;
data combined;
	merge combined (in=in1) denice (keep=Consortium_ID in=in2);
	by Consortium_ID;
	if in1 and in2;
run;




/*****Make changes to combined dataset*****/
data simpleSurvival;
	set combined;

	*Update progression variables;
	if AssessmentDate < ProgressionDate then AssessmentDate = ProgressionDate;
	if Progression="" then Progression="NO";

	*Alive;
	if DeathDate="." then Alive=1;
	else Alive=0;

	*PFS censored people - alive or no progression by assessment date;
	if Alive=1 AND Progression="NO" then PFSStatus=0;
	else PFSStatus=1;

	*PFS followup time;
	if Progression="YES" then PFSTime=ProgressionDate-TreatmentStartDate;
	else if Alive=0 then PFSTime=DeathDate-TreatmentStartDate;
	else if PFSStatus=0 then PFSTime=AssessmentDate-TreatmentStartDate;
	
	*OS censored people - alive;
	if Alive=1 then OSStatus=0;
	else OSStatus=1;

	*OS followup time;
	if Alive=0 then OSTime=DeathDate-TreatmentStartDate;
	else if Alive=1 then OSTime=AssessmentDate-TreatmentStartDate;

	*Update time variables to months;
	PFSTime=(PFSTime/365.25) * 12;
	OSTime=(OSTime/365.25) * 12;

	label PFSTime="Time (months)" OSTime="Time (months)";
	format Age_Cat age_fmt. calc_cat crcl_fmt. prior_treat_tax trt_fmt. White race_fmt. Performance_cat perf_fmt.;
run;
/********************END - RUN ALL THE CODE IN THIS BLOCK TO CREATE THE USEABLE DATASET - END ********************/








/*****Kaplan Meir Analysis*****/
*OS by Sex;
proc lifetest data=simpleSurvival CONFTYPE=linear;
	time OSTime * OSStatus(0);
	strata Sex;
run;

*PFS by Sex;
proc lifetest data=simpleSurvival CONFTYPE=linear;
	time PFSTime * PFSStatus(0);
	strata Sex;
run;

*PFS macro;
%macro PFS(strataVar);
proc lifetest data=simpleSurvival plots=(lls);
	time PFSTime * PFSStatus(0);
	strata &strataVar;
run;
%mend PFS;

*Run PFS on a variety of variables;
%PFS(Age_Cat);
%PFS(White);
%PFS(Performance_cat);
%PFS(calc_cat);
%PFS(renalfunction);
%PFS(Prior_cyctectomy);
%PFS(prior_treat_tax);




/*****Univariate Cox Analysis*****/
*Keep only relevant variables;
data coxSurvival;
	set simpleSurvival(keep=Consortium_ID Sex Age_Cont Age_Cat White Performance_cat Performance_cont calc_cat calc_creatinine renalfunction
					   Prior_cyctectomy prior_treat_tax PFSTime PFSStatus);
run;

*Univariate cox analysis for continuous variables;
%macro coxCont(contVar);
proc phreg data = coxSurvival;
	model PFSTime*PFSStatus(0) = &contVar / type1;
	hazardratio &contVar;
run;
%mend coxCont;

*Univariate cox analysis for categorical variables;
%macro coxCat(catVar, refName);
proc phreg data = coxSurvival;
	class &catVar(ref=&refName);
	model PFSTime*PFSStatus(0) = &catVar / type1;
	hazardratio &catVar / diff=ref;
run;
%mend coxCat;

*Run the cox analyses;
%coxCat(Sex, "Male");
%coxCat(Age_Cat, "25-56.9");
%coxCat(White, "White");
%coxCat(Performance_cat, "100-90"); *Significant;
%coxCat(calc_cat, "19-42.9");
%coxCat(renalfunction, "Normal Renal function");
%coxCat(prior_treat_tax, "No prior treatment for advanced disease"); *Significant;
%coxCont(Age_Cont);
%coxCont(calc_creatinine);
%coxCont(Performance_cont);




/*****Multivariate selection*****/
*Manual;
proc phreg data=coxSurvival;
	class Performance_cat(ref="100-90") prior_treat_tax(ref="No prior treatment for advanced disease") Age_Cat(ref="25-56.9") Sex(ref="Male");
	model PFSTime*PFSStatus(0) = Performance_cat Age_Cat prior_treat_tax Sex Age_Cont;
	hazardratio Performance_cat / diff=ref;
	hazardratio Age_Cat / diff=ref;
	hazardratio Sex / diff=ref;
	hazardratio prior_treat_tax / diff=ref;
	hazardratio Age_Cont;
run;

*Stepwise;
proc phreg data=coxSurvival;
	class Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax; 
	model PFSTime*PFSStatus(0) = Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax Age_Cont calc_creatinine /
		  selection=stepwise slentry=0.20 slstay=0.20;
run;

*Backward elimination;
proc phreg data=coxSurvival;
	class Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax; 
	model PFSTime*PFSStatus(0) = Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax Age_Cont calc_creatinine /
		  selection=backward slentry=0.20 slstay=0.20;
run;

*Forward selection;
proc phreg data=coxSurvival;
	class Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax; 
	model PFSTime*PFSStatus(0) = Sex Age_Cat White Performance_cat calc_cat renalfunction Prior_cyctectomy prior_treat_tax Age_Cont calc_creatinine /
		  selection=forward slentry=0.20 slstay=0.20;
run;




/*****Patients divided by # of events*****/
%macro eventCounter(catVar);
proc freq data=coxSurvival;
	tables &catVar*PFSStatus;
run;
%mend eventCounter;

%eventCounter(Age_Cat);
%eventCounter(White);
%eventCounter(Performance_cat);
%eventCounter(renalfunction);
%eventCounter(calc_cat);
%eventCounter(prior_treat_tax);
%eventCounter(Sex);




/*****Stable disease lasting at least 12 weeks*****/
*Note -> Must combine with response data set check12weeks;
data check12weeksresponse;
	set simpleSurvival (keep=Consortium_ID PFSTime Sex);
run;

proc sort data=check12weeks; by Consortium_ID; run;
proc sort data=check12weeksresponse; by Consortium_ID; run;
data check12;
	merge check12weeks (in=in1) check12weeksresponse (in=in2);
	by Consortium_ID;
	if in1 and in2;

	if PFSTime >=3 then greaterThan12=1;
	else greaterThan12=0;
run;

proc freq data=check12;
	tables Sex*greaterThan12;
run;


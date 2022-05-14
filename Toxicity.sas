/*****IMPORT DATA SETS*****/
*IMPORT TOXICITY DATA;
proc import OUT=toxicities DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload06049_2017Mar22.xls" DBMS=xls REPLACE; SHEET="Toxicities"; GETNAMES=YES; run;
data toxicities; set toxicities (keep=Consortium_ID Toxicity_Code MedDRA_LLT___CTEP_Term Grade System Attribution Course_Number); run; 

*IMPORT DEMOGRAPHIC DATA;
data demographics; set "C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\deniceexportmain.sas7bdat" (keep=Consortium_ID Sex); run;

*IMPORT MAX COURSE COUNT DATA;
proc import OUT=drug DATAFILE="C:\Users\jluu\Dropbox\Research\Groshen\PHII-75\Data\datadownload06049_2017Mar22.xls" DBMS=xls REPLACE; SHEET="Drug"; GETNAMES=YES; run;
proc sort data=drug; by Consortium_ID DESCENDING Course_Number; run;
proc sort data=drug nodupkey; by Consortium_ID; run;
data drug;
	set drug (keep=Consortium_ID Course_Number);
	if Consortium_ID="" then delete;
	rename Course_Number=Max_Course_Number;
run;




/*****MERGE DATASETS AND CLEAN DATA*****/
proc sort data=toxicities; by Consortium_ID; run;
data combined;
	merge demographics drug toxicities (rename=(MedDRA_LLT___CTEP_Term=Toxicity));
	by Consortium_ID;

	/*Remove missing IDs and invalid IDs*/
	if Consortium_ID="" or Consortium_ID="CHI-086" or Consortium_ID="PAS-153" or Consortium_ID="UCD-012" or Consortium_ID="UCD-015" or Consortium_ID="USC-002"
	   or Consortium_ID="USC-008" or Consortium_ID="USC-011" or Consortium_ID="USC-017" or Consortium_ID="USC-019" or Consortium_ID="USC-020" or Consortium_ID="USC-023"
       or Consortium_ID="USC-025" or Consortium_ID="USC-028" or Consortium_ID="USC-041" then delete;

	/*Change grade variable format*/
	Grade_num = input(Grade, 8.);
	drop Grade;
	rename Grade_num=Grade;

	/*Remove unlikely and unrelated attributions*/
	if Attribution="Unlikely" or Attribution="Unrelated" then delete;

	/*Delete or combine systems*/
	if System="DEATH" or System="Injury, poisoning and procedural complications" or System="SYNDROMES" or System="OCULAR/VISUAL" or System="Eye disorders" 
		or System="Investigations" or System="AUDITORY/EAR" or System="Psychiatric disorders" then delete;
	if System="BLOOD/BONE MARROW" or System="LYMPHATICS" or System="HEMORRHAGE/BLEEDING" then System="Blood and lymphatic system disorders";
	if System="GASTROINTESTINAL" then System="Gastrointestinal disorders";
	if System="INFECTION" then System="Infections and infestations";
	if System="METABOLIC/LABORATORY" then System="Metabolism and nutrition disorders";
	if System="VASCULAR" or System="CARDIAC ARRHYTHMIA" or System="CARDIAC GENERAL" or System="Cardiac disorders" then System="Vascular disorders";
	if System="NEUROLOGY" then System="Nervous system disorders";
	if System="PAIN" or SYSTEM="CONSTITUTIONAL SYMPTOMS" or System="MUSCULOSKELETAL/SOFT TISSUE" or System="Musculoskeletal and connective tissue disorders" 
		then System="General disorders and administration site conditions";
	if System="DERMATOLOGY/SKIN" then System="Skin and subcutaneous tissue disorders";
	if System="PULMONARY/UPPER RESPIRATORY"	then System="Respiratory, thoracic and mediastinal disorders";
	if System="RENAL/GENITOURINARY" then System="Renal and urinary disorders";

	/*Delete or combine toxicities*/
	if Toxicity="Leukocyte count decreased" or Toxicity="White blood cell decreased" then delete;
	if Toxicity="Alanine aminotransferase increased" or Toxicity="Alkaline phosphatase increased" or Toxicity="Aspartate aminotransferase increased" then Toxicity="Liver investigation";
	if Toxicity="Muscle weakness lower limb" then Toxicity="Muscle weakness";
	if Toxicity="Urinary tract infection" or Toxicity="Kidney infection" or Toxicity="Bladder infection" then Toxicity="GU infection";
	if Toxicity="Pneumonia" or Toxicity="Upper respiratory infection" or Toxicity="Bronchitis" then Toxicity="Lung infection";
	if Toxicity="Abdominal pain" or Toxicity="Anorexia" or Toxicity="Dehydration" then System="Gastrointestinal disorders";
	if Toxicity="Creatinine increased" or Toxicity="Liver investigation" then System="Metabolism and nutrition disorders";

	/*Categorize hematologic and non-hematologic*/
	if Toxicity="Anemia" or Toxicity="Febrile neutropenia" or Toxicity="CD4 lymphocytes decreased" or Toxicity="Lymphocyte count decreased"
		or Toxicity="Neutrophil count decreased" or Toxicity="Platelet count decreased" then Hematologic="T";
	else
		Hematologic="F";
run;




/*****TOXICITY DESCRIPTIVE TABLE ANALYSIS*****/
data toxicity_table; set combined; run;

/*Obtain the maximum grade toxicities for each ID*/
proc sort data=toxicity_table; by Consortium_ID Toxicity_Code DESCENDING Grade; run;
proc sort data=toxicity_table nodupkey; by consortium_id Toxicity_Code; run;
proc sort data=toxicity_table; by Toxicity; run;

/*Clean up the data, add max grade count and total toxicity count columns*/
proc means data=toxicity_table max noprint;
	class Toxicity;
	var Grade;
	output out=main_table_max n=total_toxicity_count max=max_grade_count;
run;

data main_table;
	merge main_table_max toxicity_table;
	by Toxicity;
	drop _TYPE_ _FREQ_;

	/*Remove toxicities with <15 events and no grade 3 or above events*/
	if Toxicity="" then delete;
	if total_toxicity_count<15 and max_grade_count<3 then delete;
run;

/*FREQUENCY TABLE: Main table of toxicity type and grade, by gender and system*/
proc sort data=main_table;
	by System;
run;

proc freq data=main_table;
    by System;
	tables Sex*Toxicity*Grade / norow nocol nopercent;
run;



/*****Highest grade toxicity*****/
data hgt;
	set combined (keep=Consortium_ID Grade Hematologic Sex);

	*Grade 4+ hematologic toxicity;
	if Hematologic='T' and Grade >=4 then G4HT=1;
	else G4HT=0;

	*Grade 3+ non-hematologic toxicity;
	if Hematologic='F' and Grade >=3 then G3NHT=1;
	else G3NHT=0;

	*Any grade 4+ toxicity;
	if Grade >=4 then G4T=1;
	else G4T=0;
run;

proc sort data=hgt; by DESCENDING Grade; run;
proc sort data=hgt nodupkey; by consortium_id Hematologic; run;

proc freq data=hgt;
	where Hematologic='T';
	tables Sex*G4HT;
run;

proc freq data=hgt;
	where Hematologic='F';
	tables Sex*G3NHT;
run;

proc freq data=hgt;
	tables Sex*G4T;
run;



/*****Competing Risks*****/
*Formatting for competing risks plots;
proc format; value GenderFormat 1="Male" 2="Female"; run;
data risk; Gender=1; output; Gender=2; output; format Gender GenderFormat.; run;

*Main survival analysis dataset;
data kaplan;
	set combined (keep=Sex Consortium_id Grade Hematologic Max_Course_number Course_number);

	*Re-format course_number into numeric;
	Minimum_Course_number = input(Course_number, 8.);
	drop Course_number;

	/*Change sex to numeric for competing-risk plot*/
	if Sex="Male" then Gender=1;
	if Sex="Female" then Gender=2;
	format Gender GenderFormat.;

	/*Remove missing adverse events*/
	if Grade="." then delete;
run;

/*Dummy dataset for modification*/
data kaplan_table;
	set kaplan;
	where Grade >= 3;
	failure_time=Minimum_Course_number;

	/*Create status variable for competing risks: 0=censored, 1=grade 3+ AE, 2=off treatment before g3+ AE*/
	status=1;
run;

/*Only retrieve the minimum failure time (Grade>=3)*/
proc sort data=kaplan_table; by Consortium_ID Minimum_Course_number; run;
proc sort data=kaplan_table nodupkey; by Consortium_ID Grade Hematologic; run;

/*Create the plotting data set*/
proc sort data=kaplan nodupkey; by consortium_id; run;
proc sort data=kaplan_table; by consortium_id; run;
data kaplan_combined_plot;
	update kaplan kaplan_table;
	by consortium_id;

	/*Update the status variable for these patients*/
	if status ne 1 then status=2;
	/*Censor the two ongoing patients*/
	if consortium_id="COH-126" or consortium_id="USC-116" then status=0;
	if failure_time="." then failure_time=Max_Course_Number;

	label failure_time="# of courses until 1st grade 3+ adverse event";
run;

/*Plot the competing risks graph by hematologic category*/
proc sort data=kaplan_combined_plot; by Hematologic; run;
proc phreg data=kaplan_combined_plot plot(overlay=stratum range=(0,15))=cif;
	by Hematologic;
	class Gender / order=internal ref=first param=glm;
	model failure_time*status(0) = Gender / eventcode=1;
	baseline covariates=risk;
run;

/*Plot the combined competing risks graph*/
proc phreg data=kaplan_combined_plot plot(overlay=stratum range=(0,15))=cif;
	class Gender / order=internal ref=first param=glm;
	model failure_time*status(0) = Gender / eventcode=1;
	baseline covariates=risk;
run;



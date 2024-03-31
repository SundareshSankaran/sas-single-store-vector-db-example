/*-----------------------------------------------------------------------------------------*
   
   Create Test Dataset, to support Single Step Vector Capabilities: Demo
   
   This program supports Single_Store_Vector_Capabilities.sas to show vector database 
   capabilities
   
   Sample data: HuggingFace datasets, https://huggingface.co/datasets/KShivendu/dbpedia-entities-openai-1M/viewer

   i.   Data has been downloaded as (multiple) json files of 100 records each.
   ii.  Test data initially will consist of just 100 records. Will be swapped for a larger 
        dataset once code established.   

  This uses paths which are specific to a SAS Viya environment. Check the same and replace 
  with your paths where neccessary.

  v1.0 - 28 MAR 2024
*------------------------------------------------------------------------------------------*/
/*-----------------------------------------------------------------------------------------*
  Create JSON libname pointing to json file
*------------------------------------------------------------------------------------------*/

libname dbpdata json "/mnt/viya-share/data/sstoretest/file_100.json";

/*-----------------------------------------------------------------------------------------*
  Create  libname for the target dataset - MAY NOT be NEEDED
*------------------------------------------------------------------------------------------*/
/* libname dbpdb "/mnt/azurefiles/data/sstoretest/"; */


/*-----------------------------------------------------------------------------------------*
 Connecting to CAS so that we can use PUBLIC and longer var lengths
*------------------------------------------------------------------------------------------*/

cas ss; 
caslib _ALL_ assign;

/*-----------------------------------------------------------------------------------------*
Merge embeddings with other data 
*------------------------------------------------------------------------------------------*/

data PUBLIC.newdata (keep = P4 value);
  set dbpdata.alldata;
  where P1 = "rows" and V=1;
  if P3="" then P3=P2;
  if P4 ="" then P4=P3;
run;


data PUBLIC.newdata / single=yes;
  length obs 8.;
  retain obs;
  if _n_ = 1 then obs=0;
  set PUBLIC.newdata   ;
  if P4 = "row_idx" then obs =obs+1;
  run;

/* Transpose public.newdata using values in P4 as columns */;

proc transpose data = PUBLIC.newdata out = public.transposed_data;
  by obs;
  id P4;
  var value;
run;


data PUBLIC.transposed_data_100 (keep=row_idx text title vector_string);
set PUBLIC.transposed_data;
    length vector_string varchar(*);
    array vect(1536) openai1 - openai1536;
    vector_string = "[";
    do i = 1 to 1536;
      vector_string = compbl(vector_string||put(vect(i),30.26)||",");
    end;
    vector_string = compbl(substr(vector_string,1,length(vector_string)-1)||"]");
run;

proc print data = public.transposed_data_100 (obs=10);
  var text vector_string;
quit;


proc cas;
    table.save /
        table = {name="transposed_data_100", caslib="PUBlIC"},
        name= "vector_data_100",
        caslib="PUBLIC",
        replace=True
        ;
quit;

cas ss terminate;


/*


NOTE: There were 100 observations read from the data set DBPDATA.ROWS_ROW.
NOTE: There were 100 observations read from the data set DBPDATA.ROW_OPENAI.
NOTE: The data set WORK.DBPDATA_100 has 100 observations and 1542 variables.
NOTE: DATA statement used (Total process time):
      real time           0.04 seconds
      cpu time            0.05 seconds

      */;


      /* proc contents data=work.dbpdata_100 varnum;
      run; */

      /* print 2 rows of dbpdata_100 - codegen via SAS Viya Copilot */
/* proc print data=work.dbpdata_100(obs=2);
      run; */


/*-----------------------------------------------------------------------------------------*
  Tips and observations
  ---------------------

  Embeddings including decimals and signs might run to 9 characters.  9 * 1536 plus
  need to add 1535 commas and 2 braces to open and close. 

  A varchar in PUBLIC (i..e. CAS data ) might be better than SAS.
*------------------------------------------------------------------------------------------*/

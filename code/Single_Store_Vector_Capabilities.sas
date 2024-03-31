/*-----------------------------------------------------------------------------------------*
   Single Step Vector Capabilities: Demo
   
   This program demonstrates SAS and Single Store to:

   i.   Define a table structure to hold vector data in Single Store (RDBMS)
   ii.  Hydrate table with vector data, text data and additional metadata
   iii. Create a query vector mimicking real-world search operations, consisting of word 
        embeddings which are passed to the database.
   iv.  Execute similarity search within Single Store table & retrieve top k similar results.
   v.   To Do (future): vary search and indexing parameters as required.   

   v 1.0 30 Mar 2024
*------------------------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------------------*
   User-defined parameters (environment-specific values have been removed. 
   Please fill in with values specific to your environment)
*------------------------------------------------------------------------------------------*/
/*
%let host = " ";
%let port =  ;
%let user = " ";
%let pass = " ";
%let ssl_ca_location="/a/path/to/your/trustedcerts";
%let dbase = test;  /* DON'T QUOTE */
*/;

/*-----------------------------------------------------------------------------------------*
   Note: Authentication patterns may vary depending on the environment in which the code is
   used. You're advised to update the authentication pattern accordingly, possibly by using an 
   authentication domain. 
 
   Generated from SAS Viya Copilot explanation, 29 Mar 2024
*------------------------------------------------------------------------------------------*/

/* Define macro variable k to control the top number of matches for similarity search */
%let k = 4; 

/*-----------------------------------------------------------------------------------------*
   Assign a value (default: 'db_vector_table') to the macro variable 'db_table' which refers
   to the target table in Single Store.
*------------------------------------------------------------------------------------------*/

%let db_table = db_vector_table; 

/*-----------------------------------------------------------------------------------------*
   Set the macro variable num_dimensions. This refers to the number of dimensions expected 
    from the emmbedding. OpenAI embedding model uses 1536 dimensions.
*------------------------------------------------------------------------------------------*/

%let num_dimensions = 1536;


/*-----------------------------------------------------------------------------------------*
   This SAS code establishes a connection to the SAS Cloud Analytic Services (CAS) server. 
   There are two main reasons for establishing this connection.

   Firstly, a CAS table is being used for data loading. CAS tables are designed to handle 
   long vector strings more efficiently compared to traditional SAS tables. Therefore, by 
   connecting to CAS, the code can take advantage of this feature.

   Secondly, by establishing a connection to CAS and creating a CAS library (caslib), that 
   same caslib can be repurposed as a libname for Single Store in compute. This means that 
   the caslib can be used as a reference to access and manipulate the data stored in the  
   CAS server within the compute environment.

   Generated from SAS Viya Copilot explanation, 29 Mar 2024
*------------------------------------------------------------------------------------------*/

cas ss;

caslib s2 dataSource=(srctype='singlestore',
   database="&dbase.",
   host=&host.,
   pass=&pass.,
   port=&port.,
   user=&user.
   /* multipassMemory="cache" */
)  libref = s2;


/*-----------------------------------------------------------------------------------------*
   Define a table within Single Store database
*------------------------------------------------------------------------------------------*/

proc sql;
   connect to sstore (
   host = &host.
   port = &port.
   user= &user.
   pass= &pass.
   database= &dbase. 
   ssl_ca=&ssl_ca_location.
   );

   execute(
      CREATE TABLE &dbase..&db_table. (
         _id CHAR(150) NOT NULL,   
         title CHAR(200), 
         text TEXT,
         openai VECTOR(&num_dimensions.) not null
      )
   ) by sstore;

quit;


/*-----------------------------------------------------------------------------------------*
   The 'vector' data has been created through Create_Test_Dataset.sas accessing a dataset
   with text, title and OpenAI generated embeddings.  Data is a subset of
   https://huggingface.co/datasets/KShivendu/dbpedia-entities-openai-1M
*------------------------------------------------------------------------------------------*/

proc cas;
   table.loadTable /
      path = "vector_data_100.sashdat",
      caslib = "PUBLIC",
      casout = {name="temp_vector_table", caslib="S2", replace=True}
   ;
quit;

/*-----------------------------------------------------------------------------------------*
  Table saved to S2 
*------------------------------------------------------------------------------------------*/

proc casutil incaslib="s2" outcaslib="s2";
   save casdata= "temp_vector_table"
;
quit;

/*-----------------------------------------------------------------------------------------*
  Hydrating the vector table.  Here, string variable containing embeddings are cast to vector 
  and loaded to target
*------------------------------------------------------------------------------------------*/

proc sql;
   connect to sstore (
      host = &host.
      port = &port.
      user= &user.
      pass= &pass.
      database= &dbase. 
      ssl_ca=&ssl_ca_location.
   );

   execute(
      insert into &dbase..&db_table.(
         select 
            row_idx :> CHAR(150) as _id, 
            title :> CHAR(200) as title,
            text :> TEXT as text,
            vector_string :> VECTOR(&num_dimensions.) as openai 
         from &dbase..temp_vector_table 
         ) 
   ) by sstore;

quit;

/*-----------------------------------------------------------------------------------------*
  Let's find a query vector.  
  Future placeholder: Query starts off with a call to an embedding service, 
  which begets the vector string, which is used to match with data.
*------------------------------------------------------------------------------------------*/

data s2.query_vector ;
set s2.temp_vector_table;
   if title = "Agatha Christie";
run;


/*-----------------------------------------------------------------------------------------*
  THIS search is carried out inside the database. We are pulling the top 4 similar titles
*------------------------------------------------------------------------------------------*/

proc casutil incaslib="s2" outcaslib="s2";
   save casdata= "query_vector" replace
;
quit;

/*-----------------------------------------------------------------------------------------*
  All search types (based on different distance measures) deliberately executed separately
  to enable time capture in future.
*------------------------------------------------------------------------------------------*/

/*-----------------------------------------------------------------------------------------*
  Dot Product search.
*------------------------------------------------------------------------------------------*/
proc sql;
   connect to sstore (
      host = &host.
      port = &port.
      user= &user.
      pass= &pass.
      database= &dbase.
      ssl_ca=&ssl_ca_location.
   );

   select * from connection to sstore (
      SELECT 
         a.title, 
         b.title, 
         a.vector_string :> VECTOR(&num_dimensions.) <*> b.openai AS score_dot_product
      FROM 
         test.query_vector a , test.&db_table. b
      ORDER BY score_dot_product DESC
      LIMIT &k.
   );

quit;


/*-----------------------------------------------------------------------------------------*
  Euclidean distance search (use infix operator <->)
*------------------------------------------------------------------------------------------*/
proc sql;
   connect to sstore (
      host = &host.
      port = &port.
      user= &user.
      pass= &pass.
      database= &dbase.
      ssl_ca=&ssl_ca_location.
   );

   select * from connection to sstore (
      SELECT 
         a.title, 
         b.title, 
         a.vector_string :> VECTOR(&num_dimensions.) <-> b.openai AS score_euclidean_distance
      FROM 
         test.query_vector a , test.&db_table. b
      ORDER BY score_euclidean_distance ASC
      LIMIT &k.
   );

quit;

/*-----------------------------------------------------------------------------------------*
  Cosine similarity search ( translates to the dot product between normalized vector values)
  Note the additional overhead of user-defined functions.  Vector arithmetic operations exist 
  out-of-the-box in Single Store, unfortunately not normalization functions which make use 
  of those operations.
*------------------------------------------------------------------------------------------*/

proc sql;
   connect to sstore (
      host = &host.
      port = &port.
      user= &user.
      pass= &pass.
      database= &dbase.
      ssl_ca=&ssl_ca_location.
   );

   execute(
      CREATE or REPLACE FUNCTION normalize(v VECTOR(&num_dimensions.)) RETURNS VECTOR(&num_dimensions.) AS 
         DECLARE 
            squares VECTOR(&num_dimensions.) = vector_mul(v,v); 
            length FLOAT = sqrt(vector_elements_sum(squares));
         BEGIN 
         RETURN scalar_vector_mul(1/length, v);
         END 
   ) by sstore;

   select * from connection to sstore (
      SELECT 
         a.title, 
         b.title, 
         normalize(a.vector_string :> VECTOR(&num_dimensions.)) <*> normalize(b.openai) AS score_cosine_similarity
      FROM 
         test.query_vector a , test.&db_table. b
      ORDER BY score_cosine_similarity DESC
      LIMIT &k.
   );

quit;

/*-----------------------------------------------------------------------------------------*
  Cosine distance search (which is the opposite of cosine similarity).
*------------------------------------------------------------------------------------------*/
proc sql;
   connect to sstore (
      host = &host.
      port = &port.
      user= &user.
      pass= &pass.
      database= &dbase.
      ssl_ca=&ssl_ca_location.
   );

   execute(
      CREATE or REPLACE FUNCTION normalize(v VECTOR(&num_dimensions.)) RETURNS VECTOR(&num_dimensions.) AS 
         DECLARE 
            squares VECTOR(&num_dimensions.) = vector_mul(v,v); 
            length FLOAT = sqrt(vector_elements_sum(squares));
         BEGIN 
         RETURN scalar_vector_mul(1/length, v);
         END 
   ) by sstore;


   select * from connection to sstore (
      SELECT 
         a.title, 
         b.title, 
         1 - (normalize(a.vector_string :> VECTOR(&num_dimensions.)) <*> normalize(b.openai)) AS score_cosine_distance
      FROM 
         test.query_vector a , test.&db_table. b
      ORDER BY score_cosine_distance ASC
      LIMIT &k.
   );


   quit; 

/*-----------------------------------------------------------------------------------------*
   Optional:
   Remove table as a cleanup activity. Actively use this while developing / modifying code.
*------------------------------------------------------------------------------------------*/


proc sql;
   connect to sstore (
   host = &host.
   port = &port.
   user= &user.
   pass= &pass.
   database= "&dbase." 
   ssl_ca="/security/trustedcerts.pem"
   );

   execute(DROP TABLE &dbase..&db_table.) by sstore;
   execute(DROP TABLE &dbase..temp_vector_table) by sstore;
   /* execute(DROP TABLE &dbase..query_vector) by sstore; */

   quit; 


   cas ss terminate;


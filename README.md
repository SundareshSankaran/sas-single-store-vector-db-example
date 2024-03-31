# Single Store as a vector database
Demo Single Store's capabilities as a vector database interacting with SAS, backed by a new VECTOR datatype from version 8.5 and similarity search functions resident within database.

## Contents
1. [Annotated code with basic capabilities](./code/Single_Store_Vector_Capabilities.sas)
2. [Prerequisites](##prerequisities)
3. [Instructions](##instructions)
4. [Data](#data-used-in-this-repo)
5. [Contact and version details](#contact)

## Prerequisities

1. Environment with a SAS Viya with Single Store license, version 2024.02 or later.
2. Single Store version 8.5 or later (should get updated when Viya's updated / installed with 2024.02 monthly stable or later)

## Instructions
1. Before running code provided, the following is recommended:
   1. Make a copy of [dotenv_template](dotenv_template.sas) as dotenv.sas in your local/ working area
   2. Fill in dotenv.sas with your environment-specific variables and run first. The macro variables in dotenv.sas will be used in the example programs.
   3. As the above includes authentication information for your Single Store repo, do not save dotenv.sas with this repo. dotenv.sas has been added to the [.gitignore](./.gitignore) file.
2. Run [Single_Store_Vector_Capabilities.sas](./code/Single_Store_Vector_Capabilities.sas) for a basic demo.  If you're running this on viya4-stable, lines 107 - 120 of the program makes use of a table resident within that environment.  For other environments, you are free to modify the code to use another dataset or include the data referred. An [example](./code/Create_Test_Dataset.sas) is provided to help you with the same.

## Data used in this repo
Purely for purposes of example, this uses data from a Hugging Face repository which contains 1M articles from dbpedia with a title, abstract (text), and an OpenAI embedding of the abstract. The data is located [here](https://huggingface.co/datasets/KShivendu/dbpedia-entities-openai-1M). Refer to the Hugging Face repo frequently to check for changes to data usage terms or license.

Otherwise, a **suggested** data pattern would run on the following lines.


|Field   |Data Type   |Description   |Comments   |
|--------|------------|--------------|-----------|
|ID      |Int or char |An unique ID column for the observation.|   |
|Text      |Char, Varchar or Text |Text data which forms basis for search|   |
|Embeddings      |Char or Varchar |Embeddings for the text column which should be represented in an array form, e.g. [1,2,3,4,5]| Should be sufficiently long as to hold the entire embedding sequence and closing box bracket. Numbers should not be quoted. Should contain the same number of elements as expected by the target table's VECTOR field.  |
|Metadata      |Any supported |Additional metadata you may wish to add to the table|Optional   |
--------------------------------------------------

## Contact:
- Sundaresh Sankaran (sundaresh.sankaran@sas.com)

## Change Log
- Version 1.0 (30MAR2024)


use [KIOSK_TestDB]
--main xml doc
DECLARE @mydoc xml

--Submission_Date node attributes
DECLARE @submission_date varchar(50)

--Submission node attributes
DECLARE @time varchar(50)
DECLARE @reason varchar(max)
DECLARE @status varchar(50)
DECLARE @proc varchar(5)
DECLARE @cnfemail varchar(5)
DECLARE @manager varchar(max)
DECLARE @appdate varchar(50)
DECLARE @decline varchar(max)
DECLARE @formid int

--Request node attributes
DECLARE @reqtype varchar(20)
DECLARE @reqdate varchar(50)
DECLARE @from varchar(8)
DECLARE @to varchar(8)

--Current xml block
DECLARE @Submission_Date_Block xml
DECLARE @Submission_Block xml
DECLARE @Request_Block xml

--Employee info
DECLARE @name varchar(50)

--Count Variables
DECLARE @totalrowcount int
DECLARE @totalsubmissioncount int
DECLARE @totalrequestcount int



--iterators
DECLARE @rowiter int
DECLARE @submissioniter int
DECLARE @requestiter int

--Make Cursor object to iterate over main table rows
DECLARE EmpCursor CURSOR FOR SELECT EmpName, Requests FROM Request_Submissions

--Open and fetch the first two columns from the first row into my variables
OPEN EmpCursor
FETCH NEXT FROM EmpCursor INTO @name, @mydoc

--Dont understand Fetch_Status yet, but i think it returns 1 if there are no more rows to fetch
WHILE @@FETCH_STATUS = 0
BEGIN
	--Break down the current employees request xml document into individual rows, one for each date. Create a row number column along sinde the employee name and each request date row.
	WITH EmpSubmissionDates AS (select ROW_NUMBER() OVER(ORDER BY @name ASC) as Rownum, @name as EmpName, T.c.query('.') AS SubmissionDate FROM @mydoc.nodes('/Requests/Submission_Date') as T(c))
	--Select the broke down info into a new temp table for further iterations
	SELECT Rownum, EmpName, SubmissionDate INTO #temp_table FROM EmpSubmissionDates

	--Get the count of rows in the the current temp_table
	SET @totalrowcount = (SELECT COUNT(*) FROM #temp_table)
	--Set the iterator
	SET @rowiter = 1

	WHILE @rowiter <= @totalrowcount
	BEGIN
		--Set variable to the single date block of xml in the current row
		SET @Submission_Date_Block = (SELECT SubmissionDate FROM #temp_table WHERE Rownum = @rowiter)
		--Get the Submit_Date attribute value
		SET @submission_date = (@Submission_Date_Block.value('(/Submission_Date/@Submit_Date)[1]','varchar(50)'))
		--Get the total number of submissions for the current date block
		SET @totalsubmissioncount = (SELECT @Submission_Date_Block.value('count(/Submission_Date/*)','int'))
		--Set the submission iterator
		SET @submissioniter = 1

		WHILE @submissioniter <= @totalsubmissioncount
		BEGIN
			--Set the current submission xml block
			SET @Submission_Block = (SELECT @Submission_Date_Block.query('/Submission_Date/Submission[sql:variable("@submissioniter")]'))
			--Get all current submission block attributes
			SET @time = (SELECT @Submission_Block.value('(/Submission/@Time)[1]','varchar(50)'))
			SET @reason = (SELECT @Submission_Block.value('(/Submission/@Reason)[1]','varchar(max)'))
			SET @status = (SELECT @Submission_Block.value('(/Submission/@Status)[1]','varchar(50)'))
			SET @proc = (SELECT @Submission_Block.value('(/Submission/@Processed)[1]','varchar(5)'))
			SET @cnfemail = (SELECT @Submission_Block.value('(/Submission/@ConfirmEmail)[1]','varchar(5)'))
			SET @manager = (SELECT @Submission_Block.value('(/Submission/@Manager)[1]','varchar(max)'))
			SET @appdate = (SELECT @Submission_Block.value('(/Submission/@ApproveDate)[1]','varchar(50)'))
			SET @decline = (SELECT @Submission_Block.value('(/Submission/@Decline)[1]','varchar(max)'))
			--Insert form data into the Forms table
			INSERT INTO Forms (Employee,[Status],Processed,Manager,Manager_Date,Reason,Submission_Date,Decline) VALUES (@name,@status,@proc,@manager,@appdate,@reason,@submission_date,@decline)

			--Get the auto_increment FormID value from the last insert
			SET @formid = (SELECT SCOPE_IDENTITY())
			--Get total number of request in current submission
			SET @totalrequestcount = (SELECT @Submission_Block.value('count(/Submission/*)','int'))
			--Set request iterator
			SET @requestiter = 1

			WHILE @requestiter <= @totalrequestcount
			BEGIN
				--Set the current request xml block
				SET @Request_Block = (SELECT @Submission_Block.query('/Submission/Request[sql:variable("@requestiter")]'))
				--Get all current request block attributes
				SET @reqtype = (SELECT @Request_Block.value('(/Request/@Type)[1]','varchar(20)'))
				SET @reqdate = (SELECT @Request_Block.value('(/Request/@Date)[1]','varchar(50)'))
				SET @from = (SELECT @Request_Block.value('(/Request/@From)[1]','varchar(8)'))
				SET @to = (SELECT @Request_Block.value('(/Request/@To)[1]','varchar(8)'))
				--Insert current request into the Requests table
				INSERT INTO Requests (FormID,DateOfRequest,[From],[To],[Type]) VALUES (@formid,@reqdate,@from,@to,@reqtype)
				
				SET @requestiter += 1
			END
			SET @submissioniter += 1
		END
		SET @rowiter += 1
	END
	--Drop the temp table for reuse on next iteration
	DROP TABLE #temp_table
	--Fetch the next employee row from the main table
	FETCH NEXT FROM EmpCursor INTO @name, @mydoc	
END
--Close and Clean Up
CLOSE EmpCursor
DEALLOCATE EmpCursor
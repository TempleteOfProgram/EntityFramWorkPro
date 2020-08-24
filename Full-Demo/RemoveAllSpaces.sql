USE [LMS]
GO
/****** Object:  UserDefinedFunction [dbo].[RemoveAllSpaces]    Script Date: 8/24/2020 10:29:26 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [dbo].[RemoveAllSpaces]
(
    @InputStr varchar(8000)
)
RETURNS varchar(8000)
AS
BEGIN
declare @ResultStr varchar(8000)
set @ResultStr = @InputStr
while charindex(' ', @ResultStr) > 0
    set @ResultStr = replace(@InputStr, ' ', '')

return @ResultStr
END
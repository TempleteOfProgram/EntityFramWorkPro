USE [LMS]
GO
/****** Object:  StoredProcedure [Payment].[usp_FilterPayments]    Script Date: 8/20/2020 3:59:03 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [Payment].[usp_FilterPayments]  
  @UserTypeCriteria UserType ReadOnly,
  @PaymentCodeCriteria PaymentCodeType ReadOnly,
  @PaymentStatusCiteria PaymentStatusType ReadOnly,
  @TenantId int = 0, 
  @FromDat date = null, 
  @ToDat date = null,  
  @keyword varchar(30) = '',  
  @IsScheduled bit = 0,
  @UserId int = 0, -- Owner, Payee, Broker, Property Manager
  @UserTypeId int = 0
  
AS

	DECLARE @SQLQuery AS NVARCHAR(MAX)
	DECLARE @SQLPayeeFirstNameQuery AS NVARCHAR(MAX)
 	DECLARE @SQLPayeeLastNameQuery AS NVARCHAR(MAX)
	DECLARE @SQLPayeeAddressQuery AS NVARCHAR(MAX)
	DECLARE @SQLPropertyAddressQuery AS NVARCHAR(MAX)
	DECLARE @SQLCheckNumberQuery AS NVARCHAR(MAX)
	DECLARE @SQLPayeeFULLNameQuery AS NVARCHAR(MAX)
	DECLARE @SQLPayeeFULLNameQuery2 AS NVARCHAR(MAX)
	DECLARE @SQLPayeeFULLNameQuery3 AS NVARCHAR(MAX)
	
	DECLARE @SkipMainQuery BIT = 0
	DECLARE @SkipWhere BIT = 0
	DECLARE @SkipAnd BIT = 0
	
	SET @keyword = REPLACE(@keyword, '''', '^')	 

	BEGIN
			/**['wmsCaseNumber', 'paymentDate', 'paymentPeriod', 'amount', 'paymentCode', 'checkNumber', 'payee', 'status']**/
			
			SET @SQLQuery = 'SELECT DISTINCT A.PaymentDetailId, H.WMSCaseNumber, H.TenantId, K.IsDV,

							ISNULL(convert(varchar(10), cast(A.PaymentDate as date), 101), null) [PaymentDate], 
							ISNULL(convert(varchar(10), cast(A.PaymentStartDate as date), 101), ''N/A'') [PaymentStartDate], 
							ISNULL(convert(varchar(10), cast(A.PaymentEndDate as date), 101), ''N/A'') [PaymentEndDate], 
							ISNULL(convert(varchar(10), cast(A.PaymentStartDate as date), 101), ''N/A'')  + '' - '' + ISNULL(convert(varchar(10), cast(A.PaymentEndDate as date), 101), ''N/A'') [PaymentPeriod], 
							A.Amount, 
							ISNULL(Z.Description, null) [PaymentCode], 
							X.CheckNumber, K.FirstName, K.LastName,

							(SELECT TOP 1 Y.UserId FROM Landlord.Assignment X JOIN Landlord.[User] Y ON X.UserId = Y.UserId WHERE X.PropertyId = E2.PropertyId AND X.UserTypeId = 1 AND X.IsActive = 1 ORDER BY 1 DESC ) [OwnerId], 							
							
							(SELECT TOP 1 
								CASE	
									WHEN Y.IsBusiness = 1 THEN Y.LegalName 
									WHEN Y.IsBusiness IS NULL OR Y.IsBusiness = 0 THEN Y.FirstName + '' '' + Y.LastName 									
								END 
								FROM Landlord.Assignment X JOIN Landlord.[User] Y ON X.UserId = Y.UserId WHERE X.PropertyId = E2.PropertyId AND X.UserTypeId = 1 AND X.IsActive = 1 ORDER BY 1 DESC ) [Owner],

							G.UserId [PayeeId], 

							CASE	
								WHEN G.IsBusiness = 1 THEN G.LegalName 
								WHEN G.IsBusiness IS NULL OR G.IsBusiness = 0 THEN G.FirstName + '' '' + G.LastName 
								WHEN D1.HostCaseId > 0 THEN J.FirstName + '' '' + J.LastName
							END [Payee],
							
							Y.Name [Status]

							FROM 
							Payment.PaymentDetail A 
							JOIN Payment.PaymentInstruction B ON A.PaymentInstructionId = B.PaymentInstructionId
							JOIN Tenant.Application C ON B.ApplicationId = C.ApplicationId
							JOIN Tenant.Tenant H ON C.TenantId = H.TenantId
							LEFT JOIN Landlord.PayeePaymentMode D ON B.PayeePaymentModeId = D.PayeePaymentModeId 
							LEFT JOIN Landlord.PaymentChange D1 ON D.PaymentChangeId = D1.PaymentChangeId
							LEFT JOIN Payment.UserPayment F ON D.UserPaymentId = F.UserPaymentId
							LEFT JOIN Landlord.[User] G ON F.UserId = G.UserId
							LEFT JOIN Landlord.Assignment E ON G.UserId = E.UserId 
							LEFT JOIN Landlord.Assignment E2 ON D.AssignmentId = E2.AssignmentId 
							LEFT JOIN Landlord.Property P ON E2.PropertyId = P.PropertyId
							LEFT JOIN Tenant.HostCase I ON D1.HostCaseId = I.HostCaseId
							LEFT JOIN Tenant.HouseholdMemberProfile J ON I.HostId = J.HostId
							LEFT JOIN Payment.CERTS X ON X.PaymentDetailId = A.PaymentDetailId 
							JOIN Config.PaymentStatus Y ON A.PaymentStatusId = Y.PaymentStatusId 
							LEFT JOIN Config.PaymentCode Z ON A.PaymentCodeId = Z.PaymentCodeId 
							LEFT JOIN Tenant.HouseholdMemberProfile K on H.HouseholdMemberProfileId = K.HouseholdMemberProfileId
							LEFT JOIN Landlord.Address L ON G.UserId = L.UserId '
							
			IF EXISTS (SELECT 1 FROM @UserTypeCriteria)
				BEGIN
					SET @SQLQuery = @SQLQuery + ' JOIN @UserTypeCriteria UT ON UT.UserTypeId = E.UserTypeId'
				END

			IF EXISTS (SELECT 1 FROM @PaymentCodeCriteria)
				BEGIN
					SET @SQLQuery = @SQLQuery + ' JOIN @PaymentCodeCriteria PC ON PC.PaymentCodeId = A.PaymentCodeId'
				END

			IF EXISTS (SELECT 1 FROM @PaymentStatusCiteria)
				BEGIN
					SET @SQLQuery = @SQLQuery + ' JOIN @PaymentStatusCiteria PS ON PS.PaymentStatusId  = A.PaymentStatusId'
				END

				--1 = Owner, 2 = Payee, 3 = Broker 
			IF (@UserId > 0)
				BEGIN
					IF (@UserTypeId = 1)		-- Owner
						BEGIN
							SET @SQLQuery = @SQLQuery + ' JOIN Landlord.Assignment E1 ON E.PropertyId = E1.PropertyId '
							SET @SQLQuery = @SQLQuery + ' WHERE E1.UserId = ' + cast(@UserId as varchar(20))
							SET @SkipWhere = 1
						END
					ELSE IF (@UserTypeId = 2)	-- Payee
						BEGIN
							SET @SQLQuery = @SQLQuery + ' WHERE F.UserId = ' + cast(@UserId as varchar(20))
							SET @SkipWhere = 1
						END
					ELSE IF (@UserTypeId = 3)	-- Broker
						BEGIN							
							SET @SQLQuery = @SQLQuery + ' JOIN Landlord.Leasing M ON E.UnitId = M.UnitId '
							SET @SQLQuery = @SQLQuery + ' WHERE M.BrokerId = ' + cast(@UserId as varchar(20)) +  ' AND M.BrokerId IS NOT NULL '  
							SET @SkipWhere = 1
						END
				END

			IF (@TenantId > 0)
				BEGIN
					SET @SQLQuery = @SQLQuery + ' WHERE H.TenantId = ' + cast(@TenantId as varchar(20))
					SET @SkipWhere = 1
				END
 
		    IF (@IsScheduled = 1)
				BEGIN
					IF (@SkipWhere = 0)
						BEGIN
							SET @SQLQuery = @SQLQuery + ' WHERE '
							SET @SkipWhere = 1

						END
					ELSE
						BEGIN
							SET @SQLQuery = @SQLQuery + ' AND '
						END

					SET @SQLQuery = @SQLQuery + ' A.PaymentStatusId = 1 ' -- Scheduled

				END
			IF (LEN(@keyword) >= 2)
				BEGIN
					-- Check Number - Like
					IF EXISTS (SELECT 1 FROM Payment.[CERTS] X WHERE REPLACE(X.CheckNumber, '''', '^') LIKE CONCAT('%', @keyword, '%'))
						BEGIN
							IF (@SkipWhere = 0)
								BEGIN
									SET @SQLQuery = @SQLQuery + ' WHERE '
									SET @SkipWhere = 1
								END
							ELSE
								BEGIN
									SET @SQLQuery = @SQLQuery + ' AND ( '
									SET @SkipAnd = 1
								END
										
							SET @SQLQuery = @SQLQuery + ' REPLACE(X.CheckNumber, '''''''', ''^'') LIKE CONCAT(''%'', ''' + @keyword + ''' , ''%'')'						 

						END
					-- WMS Case Number
					IF EXISTS (SELECT 1 FROM Tenant.[Tenant] X WHERE REPLACE(X.WMSCaseNumber, '''', '^') LIKE CONCAT('%', @keyword, '%') )
						BEGIN
							IF (@SkipWhere = 0)
								BEGIN
									SET @SQLQuery = @SQLQuery + ' WHERE '
									SET @SkipWhere = 1
								END
							ELSE
								BEGIN
									IF (@SkipAnd = 0)
										BEGIN
											SET @SQLQuery = @SQLQuery + ' AND ('
											SET @SkipAnd = 1
										END
									ELSE
										BEGIN
											SET @SQLQuery = @SQLQuery + ' OR '
										END
								END
										
							SET @SQLQuery = @SQLQuery + ' REPLACE(H.WMSCaseNumber, '''''''', ''^'') LIKE CONCAT(''%'', ''' + @keyword + ''' , ''%'')'						 

						END
					-- Amount 
					IF EXISTS (SELECT 1 FROM Payment.PaymentDetail X WHERE REPLACE(X.Amount, '''', '^') LIKE CONCAT('%', @keyword, '%'))
						BEGIN
							IF (@SkipWhere = 0)
								BEGIN
									SET @SQLQuery = @SQLQuery + ' WHERE '
									SET @SkipWhere = 1
								END
							ELSE
								BEGIN
									IF (@SkipAnd = 0)
										BEGIN
											SET @SQLQuery = @SQLQuery + ' AND ('
											SET @SkipAnd = 1
										END
									ELSE
										BEGIN
											SET @SQLQuery = @SQLQuery + ' OR '
										END								
								END
										
							SET @SQLQuery = @SQLQuery + ' CAST(A.Amount AS varchar(20)) LIKE CONCAT(''%'', ''' + @keyword + ''' , ''%'')'						 

						END

					IF (@SkipAnd = 1)
						BEGIN
							SET @SQLQuery = @SQLQuery + ' ) '
						END
				END

			--print @SQLQuery
			--return 
			IF (@FromDat IS NOT NULL and @ToDat IS NOT NULL) -- Date Range Selected
				BEGIN
					IF (@SkipWhere = 0)
						BEGIN
							SET @SQLQuery = @SQLQuery + ' WHERE '
							SET @SkipWhere = 1

						END
					ELSE
						BEGIN
							SET @SQLQuery = @SQLQuery + ' AND '
						END


					SET @SQLQuery = @SQLQuery + ' ((' + '''' + Convert(varchar(10), @FromDat, 120) + '''' + ' BETWEEN Convert(varchar(10), A.PaymentStartDate, 120) AND Convert(varchar(10), A.PaymentEndDate, 120) '
					SET @SQLQuery = @SQLQuery + ' AND ' + '''' + Convert(varchar(10), @ToDat, 120) + '''' + ' BETWEEN Convert(varchar(10), A.PaymentStartDate, 120) AND Convert(varchar(10), A.PaymentEndDate, 120) )'
					SET @SQLQuery = @SQLQuery + ' or Convert(varchar(10), A.PaymentDate, 120) BETWEEN ' + '''' + Convert(varchar(10), @FromDat, 120) + '''' + ' AND '+ '''' + Convert(varchar(10), @ToDat, 120)+ '''' + ')'
				END	

			IF (@FromDat IS NOT NULL and @ToDat IS NULL) -- Only One Date Selected
				BEGIN
					IF (@SkipWhere = 0)
						BEGIN
							SET @SQLQuery = @SQLQuery + ' WHERE '
							SET @SkipWhere = 1

						END
					ELSE
						BEGIN
							SET @SQLQuery = @SQLQuery + ' AND ( '
						END
						 
					SET @SQLQuery = @SQLQuery + ' Convert(varchar(10), A.PaymentEndDate, 120) = ' + '''' + Convert(varchar(10), @FromDat, 120) + ''''
					SET @SQLQuery = @SQLQuery + ' or Convert(varchar(10), A.PaymentStartDate, 120) = ' + '''' + Convert(varchar(10), @FromDat, 120) + ''''
					SET @SQLQuery = @SQLQuery + ' or Convert(varchar(10), A.PaymentStartDate, 120) = ' + '''' + Convert(varchar(10), @FromDat, 120) + '''' + ')'

				END	

			SET @SQLPayeeFirstNameQuery = @SQLQuery			
			SET @SQLPayeeLastNameQuery = @SQLQuery			
			SET @SQLPayeeAddressQuery = @SQLQuery
			SET @SQLPropertyAddressQuery = @SQLQuery
			SET @SQLPayeeFULLNameQuery = @SQLQuery	
	        SET @SQLPayeeFULLNameQuery2 = @SQLQuery	
	        SET @SQLPayeeFULLNameQuery3 = @SQLQuery	
			IF (LEN(@keyword) >= 2) -- Payee First Name - Like
				BEGIN
					IF EXISTS (SELECT 1 FROM Landlord.[User] X WHERE REPLACE(X.FirstName, '''', '^') LIKE CONCAT('%', @keyword, '%'))
						BEGIN
							IF (@SkipWhere = 0)
								BEGIN
									SET @SQLPayeeFirstNameQuery = @SQLPayeeFirstNameQuery + ' WHERE '
								END 
							ELSE
								BEGIN
									SET @SQLPayeeFirstNameQuery = @SQLPayeeFirstNameQuery + ' AND '
								END

							SET @SQLPayeeFirstNameQuery = @SQLPayeeFirstNameQuery + ' REPLACE(G.FirstName, '''''''', ''^'') LIKE CONCAT(''%'', ''' + @keyword + ''' , ''%'')'							

							IF(@SkipMainQuery = 1)
								BEGIN
									SET @SQLQuery = @SQLPayeeFirstNameQuery
									SET @SkipMainQuery = 0
								END
							ELSE
								SET @SQLQuery = @SQLQuery + ' UNION ' + @SQLPayeeFirstNameQuery

						END
				END

			IF (LEN(@keyword) >= 2) -- Payee Last Name - Like
				BEGIN
					IF EXISTS (SELECT 1 FROM Landlord.[User] X WHERE REPLACE(X.LastName, '''', '^') LIKE CONCAT('%', @keyword, '%'))
						BEGIN
							IF (@SkipWhere = 0)
								BEGIN
									SET @SQLPayeeLastNameQuery = @SQLPayeeLastNameQuery + ' WHERE '
								END
							ELSE
								BEGIN
									SET @SQLPayeeLastNameQuery = @SQLPayeeLastNameQuery + ' AND '
								END
										
							SET @SQLPayeeLastNameQuery = @SQLPayeeLastNameQuery + ' REPLACE(G.LastName, '''''''', ''^'') LIKE CONCAT(''%'', ''' + @keyword + ''' , ''%'')'							

							IF(@SkipMainQuery = 1)
								BEGIN
									SET @SQLQuery = @SQLPayeeLastNameQuery
									SET @SkipMainQuery = 0
								END
							ELSE
								SET @SQLQuery = @SQLQuery + ' UNION ' + @SQLPayeeLastNameQuery

						END
				END	
				
			IF (LEN(@keyword) >= 2) -- Payee Full Name - Like  
			    BEGIN
					BEGIN -- When IsBusiness is Null
						IF EXISTS (SELECT 1 FROM Landlord.[User] X WHERE [dbo].[RemoveAllSpaces](CONCAT(X.FirstName, X.LastName)) LIKE CONCAT('%', [dbo].[RemoveAllSpaces](@keyword), '%'))
							BEGIN
								IF (@SkipWhere = 0)
									BEGIN
										SET @SQLPayeeFULLNameQuery = @SQLPayeeFULLNameQuery + ' WHERE '
									END 
								ELSE
									BEGIN
										SET @SQLPayeeFULLNameQuery = @SQLPayeeFULLNameQuery + ' AND '
									END

								SET @SQLPayeeFULLNameQuery = @SQLPayeeFULLNameQuery + ' (G.IsBusiness IS NULL OR G.IsBusiness = 0) and [dbo].[RemoveAllSpaces](CONCAT(G.FirstName, G.LastName)) LIKE CONCAT(''%'', ''' + [dbo].[RemoveAllSpaces](@keyword) + ''' , ''%'')'							

								IF(@SkipMainQuery = 1)
									BEGIN
										SET @SQLQuery = @SQLPayeeFULLNameQuery
										SET @SkipMainQuery = 0
									END
								ELSE
									SET @SQLQuery = @SQLQuery + ' UNION ' + @SQLPayeeFULLNameQuery

							END
					END
					BEGIN -- When IsBusiness is True
						IF EXISTS (SELECT 1 FROM Landlord.[User] X WHERE [dbo].[RemoveAllSpaces](X.LegalName) LIKE CONCAT('%', [dbo].[RemoveAllSpaces](@keyword), '%'))
							BEGIN
								IF (@SkipWhere = 0)
									BEGIN
										SET @SQLPayeeFULLNameQuery2 = @SQLPayeeFULLNameQuery2 + ' WHERE '
									END 
								ELSE
									BEGIN
										SET @SQLPayeeFULLNameQuery2 = @SQLPayeeFULLNameQuery2 + ' AND '
									END

								SET @SQLPayeeFULLNameQuery2 = @SQLPayeeFULLNameQuery2 + ' G.IsBusiness = 1 and [dbo].[RemoveAllSpaces](G.LegalName) LIKE CONCAT(''%'', ''' + [dbo].[RemoveAllSpaces](@keyword) + ''' , ''%'')'							

								IF(@SkipMainQuery = 1)
									BEGIN
										SET @SQLQuery = @SQLPayeeFULLNameQuery2
										SET @SkipMainQuery = 0
									END
								ELSE
									SET @SQLQuery = @SQLQuery + ' UNION ' + @SQLPayeeFULLNameQuery2

							END
					END
					BEGIN -- When HostCaseId 
					IF EXISTS (SELECT 1 FROM Tenant.HouseholdMemberProfile X WHERE [dbo].[RemoveAllSpaces](CONCAT(X.FirstName, X.LastName)) LIKE CONCAT('%', [dbo].[RemoveAllSpaces](@keyword), '%'))
						BEGIN
							IF (@SkipWhere = 0)
								BEGIN
									SET @SQLPayeeFULLNameQuery3 = @SQLPayeeFULLNameQuery3 + ' WHERE '
								END 
							ELSE
								BEGIN
									SET @SQLPayeeFULLNameQuery3 = @SQLPayeeFULLNameQuery3 + ' AND '
								END
							SET @SQLPayeeFULLNameQuery3 = @SQLPayeeFULLNameQuery3 + ' D1.HostCaseId > 0 and [dbo].[RemoveAllSpaces](CONCAT(J.FirstName,J.LastName)) LIKE CONCAT(''%'', ''' + [dbo].[RemoveAllSpaces](@keyword) + ''' , ''%'')'							

							IF(@SkipMainQuery = 1)
								BEGIN
									SET @SQLQuery = @SQLPayeeFULLNameQuery3
									SET @SkipMainQuery = 0
								END
							ELSE
								SET @SQLQuery = @SQLQuery + ' UNION ' + @SQLPayeeFULLNameQuery3

						END
				   END
				END

			IF (LEN(@keyword) >= 2) -- Payee Address - Like
				BEGIN
					IF EXISTS (SELECT 1 FROM Landlord.[Address] X WHERE [dbo].[RemoveAllSpaces](X.StreetAddress) LIKE CONCAT('%', [dbo].[RemoveAllSpaces](@keyword), '%'))
						BEGIN
							IF (@SkipWhere = 0)
								BEGIN
									SET @SQLPayeeAddressQuery = @SQLPayeeAddressQuery + ' WHERE '
								END
							ELSE
								BEGIN
									SET @SQLPayeeAddressQuery = @SQLPayeeAddressQuery + ' AND '
								END
										
							SET @SQLPayeeAddressQuery = @SQLPayeeAddressQuery + ' [dbo].[RemoveAllSpaces](L.StreetAddress) LIKE CONCAT(''%'', ''' + [dbo].[RemoveAllSpaces](@keyword) + ''' , ''%'')'

							IF(@SkipMainQuery = 1)
								BEGIN
									SET @SQLQuery = @SQLPayeeAddressQuery
									SET @SkipMainQuery = 0
								END
							ELSE
								SET @SQLQuery = @SQLQuery + ' UNION ' + @SQLPayeeAddressQuery

						END
				END			
				
			IF (LEN(@keyword) >= 2) -- Property Address - Like
				BEGIN
					IF EXISTS (SELECT 1 FROM Landlord.[Property] Pro WHERE [dbo].[RemoveAllSpaces](Pro.StreetAddress) LIKE CONCAT('%', [dbo].[RemoveAllSpaces](@keyword), '%'))
						BEGIN
							IF (@SkipWhere = 0)
								BEGIN
									SET @SQLPropertyAddressQuery = @SQLPropertyAddressQuery + ' WHERE '
								END
							ELSE
								BEGIN
									SET @SQLPropertyAddressQuery = @SQLPropertyAddressQuery + ' AND '
								END
										
							SET @SQLPropertyAddressQuery = @SQLPropertyAddressQuery + ' [dbo].[RemoveAllSpaces](P.StreetAddress) LIKE CONCAT(''%'', ''' + [dbo].[RemoveAllSpaces](@keyword) + ''' , ''%'')'

							IF(@SkipMainQuery = 1)
								BEGIN
									SET @SQLQuery = @SQLPropertyAddressQuery
									SET @SkipMainQuery = 0
								END
							ELSE
								SET @SQLQuery = @SQLQuery + ' UNION ' + @SQLPropertyAddressQuery

						END
				END	

			IF (LEN(@keyword) >= 2 AND CHARINDEX('CONCAT', @SQLQuery) = 0)
				BEGIN
					RETURN
				END

 			PRINT @SQLQuery			
			--return
 
			EXEC sp_executesql @SQLQuery, N'@UserTypeCriteria UserType readonly, @PaymentCodeCriteria PaymentCodeType readonly, @PaymentStatusCiteria PaymentStatusType ReadOnly',
					@UserTypeCriteria, @PaymentCodeCriteria, @PaymentStatusCiteria

		END

 

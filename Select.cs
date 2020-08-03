public async Task<List<T>> ExecuteStoreProcedure<T>(string nameOfStoredProc, SqlParameter paramOne = null, 
            SqlParameter paramTwo = null, SqlParameter paramThree = null, SqlParameter paramFour = null) where T : new()
        {
        /***
        //using System.Data;
        //using System.Type;
        //using System.Reflection;
        //using System.Data.SqlClient;
        
         Execute Store Procedure using 0 to 4 SqlParamer
         @retun result of sql command
        **/
            var result = new List<T>();

            using (var connection = new SqlConnection(configuration.GetConnectionString(Constants.CONNECTION_STR)))
            {
                var cmd = new SqlCommand
                {
                    Connection = connection,
                    CommandType = CommandType.StoredProcedure,
                    CommandText = nameOfStoredProc
                };
                // adding sqlParameter to sqlCommand
                if (paramOne != null)
                {
                    cmd.Parameters.Add(paramOne);
                }
                if (paramTwo != null)
                {
                    cmd.Parameters.Add(paramTwo);
                }
                if (paramThree != null)
                {
                    cmd.Parameters.Add(paramThree);
                }
                if (paramFour != null)
                {
                    cmd.Parameters.Add(paramFour);
                }

                try
                {
                    connection.Open();
                    var oDr = await cmd.ExecuteReaderAsync();

                    while (oDr.Read())
                    {
                        T t = new T();

                        for (int inc = 0; inc < oDr.FieldCount; inc++)
                        {
                            Type type = t.GetType();
                            PropertyInfo prop = type.GetProperty(oDr.GetName(inc));

                            if (prop != null)
                            {
                                var val = oDr.GetValue(inc);

                                if (val != null && !val.ToString().Equals(""))
                                {
                                    var targetType = prop.PropertyType.IsGenericType && prop.PropertyType.GetGenericTypeDefinition().Equals(typeof(Nullable<>))
                                        ? Nullable.GetUnderlyingType(prop.PropertyType) : prop.PropertyType;
                                    val = Convert.ChangeType(val, targetType);

                                    prop.SetValue(t, val, null);
                                }
                            }
                        }

                        result.Add(t);
                    }

                    oDr.Close();
                }
                catch (Exception ex)
                {
                    //err
                    Console.WriteLine(ex.Message);
                }
            }

            return result;
        }

/***

Declare @SQLQuery AS NVARCHAR(MAX)
Declare @PaymentInstructionId as int = 1166
Declare @Amount as int = 100

SET @SQLQuery = 'select * from Payment.PaymentDetail '

	BEGIN
		if @PaymentInstructionId > 0
			begin
				SET @SQLQuery = @SQLQuery +  ' where ' + 'PaymentInstructionId=' +  CAST(@PaymentInstructionId as varchar(100))
			end

		if @Amount > 0
			begin
				SET @SQLQuery = @SQLQuery + ' AND ' + ' REPLACE(Amount, '''''''', ''^'') LIKE CONCAT(''%'', ''' + CAST(@Amount as varchar(100)) + ''' , ''%'')'
			end

		print @SQLQuery
		exec sp_executesql @SQLQuery
	END

****/

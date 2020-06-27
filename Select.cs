public async Task<List<T>> ExecutePaymentSP<T>(string nameOfStoredProc, SqlParameter[] parameters) where T : new()
        {
            var result = new List<T>();
            using (var connection = new SqlConnection(configuration.GetConnectionString(Constants.CONNECTION_STR)))
            {
                var cmd = new SqlCommand
                {
                    Connection = connection,
                    CommandType = CommandType.StoredProcedure,
                    CommandText = nameOfStoredProc
                };
                foreach(var parameter in parameters)
                {
                    // adding sqlParameter to sqlCommand
                    cmd.Parameters.Add(parameter);
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
                }
            }

            return result;
        }

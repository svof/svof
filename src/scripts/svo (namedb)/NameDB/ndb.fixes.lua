function ndb.fixed_set(field, value, query)
   local db_name = field.database
   local s_name = field.sheet

   local conn = db.__conn[db_name]

   local sql_update = [[UPDATE OR %s %s SET "%s" = %s]]
   if query then
       sql_update = sql_update .. [[ WHERE %s]]
   end

   local sql = sql_update:format(db.__schema[db_name][s_name].options._violations, s_name, field.name, db:_coerce(field, value), query)

   db:echo_sql(sql)
   assert(conn:execute(sql))
   if db.__autocommit[db_name] then
      conn:commit()
   end
end
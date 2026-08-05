function Bridge.Database.Query(query, parameters)
    return MySQL.query.await(query, parameters or {})
end

function Bridge.Database.Transaction(statements)
    local queries = {}
    for index = 1, #statements do
        local statement = statements[index]
        queries[index] = {
            query = statement.query,
            values = statement.params or statement.values or {},
        }
    end

    return MySQL.transaction.await(queries)
end

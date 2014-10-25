class UserModule < ActiveRecord::Base
  trim_field :name
  belongs_to :assessment

  def self.load(moduleName,assessment_id)
    # In order to not screw with tables in the middle of the semester,
    # use badly-named variables here. I'm sorry! I'm sorry! - krivers
    return where(:name=>moduleName,:course_id=>assessment_id).first
  end

  def sql_safe(arg)
    #We are only allowing alphabetic characters 
    whitelist = [Integer,Fixnum,Float]
    if ! (whitelist.find {|c| c == arg.class }) then
      arg.gsub(/[^a-zA-Z_0-9-]/,"")
    end
    arg #Functional programs are functional 
  end

  def addColumn(field_name,data_type)
    if data_type.class != Class then
      return nil
    end
    field_name = sql_safe(field_name)
    ActiveRecord::Base.connection.execute("INSERT into module_fields
      (`user_module_id`,`name`,`data_type`)
       VALUES ('#{self.id}','#{field_name}','#{data_type}')")
  end

  def removeColumn(field_name)
    field_name = sql_safe(field_name)
    result = ActiveRecord::Base.connection.select_all("SELECT `id` from module_fields 
      WHERE `user_module_id`='#{self.id}' 
      AND `name`='#{field_name}'")
    if result.empty? then
      return nil
    end
    field_id = result[0]['id']

    ActiveRecord::Base.connection.execute("DELETE from module_data 
      WHERE `field_id`='#{field_id}'")
    ActiveRecord::Base.connection.execute("DELETE from module_fields 
      WHERE `id`='#{field_id}'")
  end
  
  def put(fieldName,data_id,data)
    fieldName = sql_safe(fieldName)
    data_id = Integer(data_id)
    data = sql_safe(data) 
    #get the ID number of that field
    result =  ActiveRecord::Base.connection.select_all("SELECT `id` from module_fields 
      WHERE `user_module_id`='#{self.id}' 
      AND `name`='#{fieldName}'")
    if result.empty? then
      return nil
    end
    field_id = result[0]['id']

    #is this an insert or an update?
    result = ActiveRecord::Base.connection.select_all("SELECT * from module_data
      WHERE `field_id`='#{field_id}' and `data_id`='#{data_id}'")
    if !result.empty? then
      #update!
      ActiveRecord::Base.connection.execute("UPDATE module_data 
        SET `data`='#{data}' WHERE `field_id`='#{field_id}'
        AND `data_id`='#{data_id}'")
    else
      #insert!
      ActiveRecord::Base.connection.execute("INSERT into module_data 
        (`field_id`,`data_id`,`data`) 
        VALUES ('#{field_id}','#{data_id}','#{data}')")
    end
  end

  def delete(fieldName,data_id)
    fieldName = sql_safe(fieldName)
    data_id = Integer(data_id)
    #get the ID number of that field
    result = ActiveRecord::Base.connection.select_all("SELECT `id` from module_fields 
      WHERE `user_module_id`='#{self.id}' 
      AND `name`='#{fieldName}'")
    if result.empty? then
      return 
    end
    field_id = result[0]['id']

    #is this an insert or an update?
    ActiveRecord::Base.connection.execute("DELETE FROM module_data 
      WHERE `field_id`='#{field_id}' and `data_id`='#{data_id}'")
  end

  def get(fieldName,data_id=nil)
    fieldName = sql_safe(fieldName)
    begin
      data_id = Integer(data_id)
    rescue
      data_id = nil
    end
    #get the ID number of that field
    result = ActiveRecord::Base.connection.select_all("SELECT `id`,`data_type` from module_fields 
      WHERE `user_module_id`='#{self.id}' 
      AND `name`='#{fieldName}'")
    if result.empty? then
      return nil
    end
    field_id = result[0]['id']  
    data_type = result[0]['data_type']

    if data_id == nil then
      result = ActiveRecord::Base.connection.select_all("SELECT * from module_data
        WHERE `field_id`=#{field_id}")
    else
      result = ActiveRecord::Base.connection.select_all("SELECT * from module_data
        WHERE `field_id`=#{field_id} AND `data_id`=#{data_id}")
    end

    if result.empty? then
      return nil
    end
    begin
      if result.many? then
        results = {}
        for r in result do
          #TODO: I put quotes in the eval to prevent the data from
          #being intepreted as a type, but I'm not sure that is 
          #'always" correct, so it should be tested under different 
          #data types. 
          results[r['data_id'].to_i] = eval("#{data_type}(\"#{r['data']}\")")
        end
        return results
      else
        return eval("#{data_type}(\"#{result[0]['data']}\")")
      end
    rescue
      puts $!
      if result.many? then
        results = {}
        for r in result do 
          results[r['data_id'].to_i] = r['data']
        end
      else
        return result[0]['data']
      end
    end
  end

  def getByVal(fieldName,data)
    fieldName = sql_safe(fieldName)
    data = sql_safe(data)
    #get the ID number of that field
    result = ActiveRecord::Base.connection.select_all("SELECT `id`,`data_type` from module_fields 
      WHERE `user_module_id`='#{self.id}' 
      AND `name`='#{fieldName}'")
    puts result
    puts result.count
    puts "restss"
    if result.empty? then
      return nil
    end
    field_id = result[0]['id']  
    COURSE_LOGGER.log("Field_id:#{field_id}")
    throw "yo"

    result = ActiveRecord::Base.connection.select_all("SELECT * from module_data
      WHERE `field_id`=#{field_id} AND `data`='#{data}'")
    if result.many? then
      results = []
      for r in result do
        results << r['data_id'].to_i
      end
      return results
    else
      return result[0]['data_id'].to_i
    end
  end
end

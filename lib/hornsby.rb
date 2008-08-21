class Hornsby
  @@record_name_fields = %w( name title username login )
  @@delete_sql = "DELETE FROM %s"
  
  if const_defined?(:RAILS_ROOT)
    FRAMEWORK_ROOT = RAILS_ROOT
  elsif const_defined?(:Merb)
    FRAMEWORK_ROOT = Merb.root
  end
  
  cattr_reader :scenarios
  @@scenarios = {}
  # @@namespaces = {}
  
  def self.build(*names)
    delete_tables
    
    scenarios = names.map {|name| @@scenarios[name.to_sym] or raise "scenario #{name} not found"}
    
    scenarios.each {|s| s.build}
  end
  
  def self.[](name)
  end
  
  def self.load(scenarios_file=nil)
    return unless @@scenarios.empty?
    
    scenarios_file ||= FRAMEWORK_ROOT+'/spec/hornsby_scenarios.rb'
    
    self.module_eval File.read(scenarios_file)
  end
  
  def self.scenario(scenario,&block)
    self.new(scenario, &block)
  end
  
  def self.namespace(name,&block)
  end
  
  def self.reset!
    @@scenarios = {}
  end
  
  def initialize(scenario, &block)
    case scenario
    when Hash
      parents = scenario.values.first
      @parents = Array === parents ? parents : [parents]
      scenario = scenario.keys.first
    when Symbol, String
      @parents = []
    else 
      raise "I don't know how to build `#{scenario.inspect}'"
    end
    
    @scenario = scenario.to_sym
    @block    = block
    
    @@scenarios[@scenario] = self
  end
  
  def say(*messages)
    puts messages.map { |message| "=> #{message}" }
  end

  def build
    #say "Building scenario `#{@scenario}'"
    @context = context = Module.new
    
    # TODO move this elsewhere
    context.module_eval do
      def self.method_missing(meth_id,*args,&block)
        begin
          rec = meth_id.to_s.classify.constantize.send(:create!, *args)
          yield(rec) if block_given?
        rescue
          super
        end
      end
    end
    
    ivars = context.instance_variables
    
    build_parent_scenarios(context)
    build_scenario(context)
    
    @context_ivars = context.instance_variables - ivars
    
    self
  end
  
  def build_scenario(context)
    surface_errors { context.module_eval(&@block) }
  end
  
  def build_parent_scenarios(context)
    @parents.each do |p|
      parent = self.class.scenarios[p] or raise "parent scenario [#{p}] not found!"

      parent.build_parent_scenarios(context)
      parent.build_scenario(context)
    end
  end

  
  def surface_errors
    yield
  rescue Object => error
    puts 
    say "There was an error building scenario `#{@scenario}'", error.inspect
    puts 
    puts error.backtrace
    puts 
    raise error
  end
  
  def self.delete_tables
    tables.each { |t| ActiveRecord::Base.connection.delete(@@delete_sql % t)  }
  end

  def self.tables
    ActiveRecord::Base.connection.tables - skip_tables
  end

  def self.skip_tables
    %w( schema_info )
  end
  
  def copy_ivars(to)
    @context_ivars.each do |iv|
      to.instance_variable_set(iv, @context.instance_variable_get(iv))
    end
  end
  
  
end


module HornsbySpecHelper
  def hornsby_scenario(*names)
    Hornsby.build(*names).each {|s| s.copy_ivars(self)}
  end
  
  def before
    puts "hornessbey, before"
  end
end
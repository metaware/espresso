class << E

  # setting controller's base URL
  #
  # if multiple paths provided, first path is treated as root,
  # and other ones are treated as canonical routes.
  # canonical routes allow controller to serve multiple roots.
  #
  def map *paths
    return if mounted?
    map! *paths
  end

  # add/update a path rule
  #
  # @note default rules
  #    - "__"   (2 underscores) => "-" (dash)
  #    - "___"  (3 underscores) => "/" (slash)
  #    - "____" (4 underscores) => "." (period)
  #
  # @example
  #    path_rule  "__d__" => "-"
  #
  #    def some__d__action
  #      # will resolve to some-action
  #    end
  #
  # @example
  #    path_rule  "!" => ".html"
  #
  #    def some_action!
  #      # will resolve to some_action.html
  #    end
  #
  # @example
  #    path_rule  /_j$/ => ".json"
  #
  #    def some_action_j
  #      # will resolve to some_action.json
  #    end
  #
  def path_rule from, to
    return if mounted?
    from = %r[#{from}] unless from.is_a?(Regexp)
    (@__e__path_rules ||= Hash[E__PATH_RULES]).update from => to
  end

  def path_rules
    @__e__sorted_path_rules ||= begin
      rules = @__e__path_rules || E__PATH_RULES
      Hash[rules.sort {|a,b| b.first.source.size <=> a.first.source.size}].freeze
    end
  end

  # allow to set routes directly, without relying on path rules.
  #
  # @example make :bar method to serve /bar, /some/url and /some/another/url
  #   def bar
  #     # ...
  #   end
  #
  #   alias_action 'some/url', :bar
  #   alias_action 'some/another/url', :bar
  #
  # @note private and protected methods usually are not publicly available via HTTP.
  #       however, if you add an action alias to such a method, it becomes public via its alias.
  #       to alias a private/protected method and keep it private,
  #       use standard ruby `alias` or `alias_method` rather than `alias_action`
  #
  # @param [String] url target URL
  # @param [Symbol] action
  def alias_action url, action
    return if mounted?
    ((@__e__alias_actions ||= {})[action]||=[]) << url
  end

  def alias_actions
    @__e__alias_actions || {}
  end

  # automatically setting URL extension and Content-Type.
  # this method will set formats for all actions.
  #
  # @example
  #
  #   class App < E
  #
  #     format '.html', '.xml', '.etc'
  #
  #   end
  #
  def format *formats
    return if mounted?
    (@__e__formats ||= []).concat formats
  end

  # setting format(s) for specific action.
  # first argument is the action name or a Regex matching multiple action names.
  # consequent arguments are the formats to be served.
  #
  # @example make :page action to serve .html format
  #
  #   class App < E
  #
  #     format_for :page, '.html'
  #
  #   end
  #
  # @example make :page action to serve .html and .xml formats
  #
  #   class App < E
  #
  #     format_for :page, '.html', '.xml'
  #
  #   end
  #
  # @example make actions that match /api/ to serve .json format
  #
  #   class App < E
  #
  #     format_for /api/, '.json'
  #
  #   end
  #
  # @example make :api action to serve .json and .xml formats
  #               and any other actions to serve .html format
  #
  #   class App < E
  #
  #     format_for :api, '.json', '.xml'
  #     format '.html'
  #
  #   end
  #
  def format_for matcher, *formats
    return if mounted?
    (@__e__formats_for ||= []) << [matcher, formats]
  end

  # allow to disable format for specific action(s).
  # any number of arguments accepted(zero arguments will have no effect).
  #
  # @example  all actions will serve .xml format,
  #           except :read action, which wont serve any format
  #
  #   format '.xml'
  #   disable_format_for :read
  #
  # @example  actions matching /api/ wont serve any formats
  #
  #   disable_format_for /api/
  #
  def disable_format_for *matchers
    return if mounted?
    (@__e__disable_formats_for ||= []).concat matchers
  end

  def formats action
    (@__e__expanded_formats || {})[action] || []
  end

  # add setups to be executed before/after given(or all) actions.
  #
  # @note setups will be executed in the order they was added
  # @note #before, #setup and #on are aliases
  #
  # @example setup to be executed before any action
  #      setup do
  #        # ...
  #      end
  #
  # @example defining the setup to be executed only before :index
  #      before :index do
  #         # ...
  #      end
  #
  # @example defining a setup to be executed after :post_login and :put_edit actions
  #      after :post_login, :put_edit do
  #        # ...
  #      end
  #
  # @example  running a setup before :blue action
  #           as well as before actions matching "red"
  #      before :blue, /red/ do
  #        # ...
  #      end
  #
  # @example running a  setup for any action on .json format
  #      on '.json' do
  #        # ...
  #      end
  #
  # @example running a  setup for :api action on .json format
  #      on 'api.json' do
  #        # ...
  #      end
  #
  def before *matchers, &proc
    add_setup :a, *matchers, &proc
  end
  alias on    before
  alias setup before

  # allow to run multiple callbacks for same action.
  # action will run its callback(s)(if any) regardless aliased callbacks.
  # callbacks will run in the order was added, that's it,
  # if an aliased callback defined before action's callback, it will run first.
  #
  # @example run :save callback on :post_crud action
  #   class App < E
  #     before :save do
  #       # ...
  #     end
  #
  #     def post_crud
  #       # ...
  #     end
  #     alias_before :post_crud, :save
  #   end
  #
  # @param [Symbol] action
  # @param [Array] others callbacks to run before given actions, beside its own callback
  #
  def alias_before action, *others
    return if mounted?
    (@__e__before_aliases ||= {})[action] = others
  end

  # (see #before)
  def after *matchers, &proc
    add_setup :z, *matchers, &proc
  end
  
  # (see #alias_before)
  def alias_after action, *others
    return if mounted?
    (@__e__after_aliases ||= {})[action] = others
  end

  def setup_aliases position, action
    if position == :a
      (@__e__before_aliases || {})[action] || []
    elsif position == :z
      (@__e__after_aliases  || {})[action] || []
    end
  end

  def add_setup position, *matchers, &proc
    return if mounted?
    (@__e__setups  ||= {})[@__e__setup_container] ||= {}
    method   = proc_to_method(:setups, position, *matchers, &proc)
    matchers = [:*] if matchers.empty?
    matchers.each do |matcher|
      (@__e__setups[@__e__setup_container][position] ||= []) << [matcher, method]
    end
  end
  private :add_setup

  def setups position, action, format
    return [] unless (s = @__e__expanded_setups) && (s = s[position]) && (s = s[action])
    s[format] || []
  end

  # add Rack middleware to chain
  def use ware, *args, &proc
    return if mounted?
    (@__e__middleware ||= []).none? {|w| w.first == ware} && 
      @__e__middleware << [ware, args, proc]
  end

  def middleware
    @__e__middleware || []
  end

  # define a block to be executed on errors.
  # the block should return a [String] error message.
  #
  # multiple error codes accepted.
  # if no error codes given, the block will be effective for any error type.
  #
  # @example handle 404 errors:
  #    class App < E
  #
  #      error 404 do |error_message|
  #        "Some weird error occurred: #{ error_message }"
  #      end
  #    end
  #
  # @param [Integer] code
  # @param [Proc] proc
  #
  def error *error_codes, &proc
    return if mounted?
    proc || raise(ArgumentError, 'Error handlers require a block')
    error_codes.any? || error_codes = [:*]
    meth = proc_to_method(:error_handlers, *error_codes, &proc)
    error_codes.each {|c| (@__e__error_handlers ||= {})[c] = [meth, proc.arity]}
  end

  def error_handler error_code
    ((@__e__error_handlers || {}).find {|k,v| error_code == k} || []).last
  end

  def rewrite rule, &proc
    proc || raise(ArgumentError, "Rewrite rules requires a block to run")
    (@__e__rewrite_rules ||= []) << [rule, proc]
  end
  alias rewrite_rule rewrite

end

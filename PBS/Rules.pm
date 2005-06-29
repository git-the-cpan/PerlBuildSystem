
package PBS::Rules ;

use PBS::Debug ;

use 5.006 ;

use strict ;
use warnings ;
use Data::TreeDumper ;
use Carp ;
 
require Exporter ;
use AutoLoader qw(AUTOLOAD) ;

our @ISA = qw(Exporter) ;
our %EXPORT_TAGS = ('all' => [ qw() ]) ;
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } ) ;
our @EXPORT = qw(AddRule AddRuleTo AddSubpbsRule ReplaceRule ReplaceRuleTo RemoveRule BuildOk) ;
our $VERSION = '0.09' ;

use File::Basename ;

use PBS::Rules::Dependers ;
use PBS::Rules::Builders ;

use PBS::Shell ;
use PBS::PBSConfig ;
use PBS::Output ;
use PBS::Constants ;
use PBS::Plugin;

use base qw(PBS::Attributes) ;

#-------------------------------------------------------------------------------

our %package_rules ;

#-------------------------------------------------------------------------------

sub GetPackageRules
{
my $package = shift ;
my $pbs_config = PBS::PBSConfig::GetPbsConfig($package) ;

my @rules_names = @_ ;
my @all_rules   = () ;

PrintInfo("Get package rules: $package\n") if defined $pbs_config->{DEBUG_DISPLAY_RULES} ;

if(exists $package_rules{$package})
	{
	return($package_rules{$package}) ;
	}
else
	{
	return({}) ;
	}
}

#-------------------------------------------------------------------------------

sub ExtractRules
{
# extracts out the rules named in @rule_names from the rules definitions $rules

#! slave rules should be kept separately say in %slave_rules
#! rules hsould be kept in sorted order
#! this sub could be 1 line long => retun $rules->{@rules_namespace} ;
	
my $rules = shift ;
my @rules_namespaces = @_ ;

my (@creator_rules, @dependency_rules, @post_dependency_rules) ;

for my $rules_namespace (@rules_namespaces)
	{
	if(exists $rules->{$rules_namespace})
		{
		for my $rule (@{$rules->{$rules_namespace}})
			{
			my ($post_depend, $meta_slave, $creator) ;
			
			for my $rule_type (@{$rule->{TYPE}})
				{
				$post_depend++ if $rule_type eq POST_DEPEND ;
				$meta_slave++ if $rule_type eq META_SLAVE ;
				$creator++ if $rule_type eq CREATOR ;
				}
				
			next if($meta_slave) ;
			
			if($creator)
				{
				push @creator_rules, $rule ;
				}
			else
				{
				if($post_depend)
					{
					push @post_dependency_rules, $rule ;
					}
				else
					{
					push @dependency_rules, $rule ;
					}
				}
			}
		}
	}

return(@creator_rules, @dependency_rules, @post_dependency_rules) ;
}

#-------------------------------------------------------------------------------

sub AddRule
{
# Depender build from the rules will return an array reference containing:
# - the value 0 and a text message if no dependencies where found
# or 
# - the value 1 and a list of dependency names

my ($package, $file_name, $line) = caller() ;
$file_name =~ s/^'// ;
$file_name =~ s/'$// ;

my $class = 'User' ;

my @rule_definition = @_ ;
RunUniquePluginSub('AddRule', $file_name, $line, \@rule_definition) ;

my $first_argument = shift @rule_definition ;
my ($name, $rule_type) ;

if('ARRAY' eq ref $first_argument)
	{
	$rule_type = $first_argument ;
	$name = shift @rule_definition ;
	}
else
	{
	if('' eq ref $first_argument)
		{
		$name = $first_argument ;
		$rule_type = [UNTYPED] ;
		}
	else
		{
		Carp::carp ERROR("Invalid rule at '$file_name:$line'. Expecting a string or an array ref as first argument.") ;
		PbsDisplayErrorWithContext($file_name,$line) ;
		die ;
		}
	}

my($depender_definition, $builder_sub, $node_subs) = @rule_definition ;

RegisterRule
	(
	  $file_name, $line
	, $package, $class
	, $rule_type
	, $name
	, $depender_definition, $builder_sub, $node_subs
	) ;
}

#-------------------------------------------------------------------------------

sub AddRuleTo
{
my ($package, $file_name, $line) = caller() ;
$file_name =~ s/^'// ;
$file_name =~ s/'$// ;

my $class = shift ;
unless('' eq ref $class)
	{
	Carp::carp ERROR("Class name expected as first argument at '$file_name:$line'") ;
	PbsDisplayErrorWithContext($file_name,$line) ;
	die ;
	}

my @rule_definition = @_ ;
RunUniquePluginSub('AddRule', $file_name, $line, \@rule_definition) ;

my $first_argument = shift @rule_definition;
my ($name, $rule_type) ;

if('ARRAY' eq ref $first_argument)
	{
	$rule_type = $first_argument ;
	$name = shift @rule_definition ;
	}
else
	{
	if('' eq ref $first_argument)
		{
		$name = $first_argument ;
		$rule_type = [UNTYPED] ;
		}
	else
		{
		Carp::carp ERROR("Invalid rule at: '$name'. Expecting a string or an array ref.") ;
		PbsDisplayErrorWithContext($file_name,$line) ;
		die ;
		}
	}

my ($depender_definition, $builder_sub, $node_subs) = @rule_definition ;

RegisterRule
	(
	  $file_name, $line
	, $package,$class
	, $rule_type
	, $name
	, $depender_definition, $builder_sub, $node_subs
	) ;
}

#-------------------------------------------------------------------------------

sub ReplaceRule
{
my ($package, $file_name, $line) = caller() ;
$file_name =~ s/^'// ;
$file_name =~ s/'$// ;

my $class = 'User' ;

my @rule_definition = @_ ;
RunUniquePluginSub('AddRule', $file_name, $line, \@rule_definition) ;

my $first_argument = shift @rule_definition ;

my ($name, $rule_type) ;

if('ARRAY' eq ref $first_argument)
	{
	$rule_type = $first_argument ;
	$name = shift @rule_definition ;
	}
else
	{
	if('' eq ref $first_argument)
		{
		$name = $first_argument ;
		$rule_type = [UNTYPED] ;
		}
	else
		{
		Carp::carp ERROR("Invalid rule at: '$name'. Expecting a string or an array ref.") ;
		PbsDisplayErrorWithContext($file_name,$line) ;
		die ;
		}
	}

my($depender_definition, $builder_sub, $node_subs) = @rule_definition ;

RemoveRule($package, $class, $name) ;

RegisterRule
	(
	  $file_name, $line
	, $package, $class
	, $rule_type
	, $name
	, $depender_definition, $builder_sub, $node_subs
	) ;
}

#-------------------------------------------------------------------------------

sub ReplaceRuleTo
{
my ($package, $file_name, $line) = caller() ;
$file_name =~ s/^'// ;
$file_name =~ s/'$// ;

my $class = shift ;

my @rule_definition = @_ ;
RunUniquePluginSub('AddRule', $file_name, $line, \@rule_definition) ;

my $first_argument = shift @rule_definition ;
my ($name, $rule_type) ;

unless('' eq ref $class)
	{
	Carp::carp ERROR("Class name expected as first argument at: $name") ;
	PbsDisplayErrorWithContext($file_name,$line) ;
	die ;
	}

if('ARRAY' eq ref $first_argument)
	{
	$rule_type = $first_argument ;
	$name = shift @rule_definition ;
	}
else
	{
	if('' eq ref $first_argument)
		{
		$name = $first_argument ;
		$rule_type = [UNTYPED] ;
		}
	else
		{
		Carp::carp ERROR("Invalid rule at: '$name'. Expecting a string or an array ref.") ;
		PbsDisplayErrorWithContext($file_name,$line) ;
		die ;
		}
	}

my ($depender_definition, $builder_sub, $node_subs) = @rule_definition ;

RemoveRule($package,$class, $name) ;
RegisterRule
	(
	  $file_name, $line
	, $package, $class
	, $rule_type
	, $name
	, $depender_definition, $builder_sub, $node_subs
	) ;
}

#-------------------------------------------------------------------------------

sub RegisterRule
{
my ($file_name, $line, $package, $class, $rule_types, $name, $depender_definition, $builder_definition, $node_subs) = @_ ;

my $pbs_config = PBS::PBSConfig::GetPbsConfig($package) ;

if(exists $package_rules{$package}{$class})
	{
	#! replace loop bellow by hash lookup
	for my $rule (@{$package_rules{$package}{$class}})
		{
		if($rule->{NAME} eq $name)
			{
			Carp::carp ERROR("'$name' name is already used for for rule defined at $rule->{FILE}:$rule->{LINE}:$package\n") ;
			PbsDisplayErrorWithContext($file_name,$line) ;
			PbsDisplayErrorWithContext($rule->{FILE},$rule->{LINE}) ;
			die ;
			}
		}
	}

my ($builder_sub, $node_subs1, $builder_generated_types) = GenerateBuilder(undef, $builder_definition, $package, $name, $file_name, $line) ;
$builder_generated_types ||= {} ;

my ($depender_sub, $node_subs2, $depender_generated_types) = GenerateDepender($file_name, $line, $package, $class, $rule_types, $name, $depender_definition, $builder_sub) ;

my $origin = '' ;
if($pbs_config->{ADD_ORIGIN})
	{
	$origin = ":$package:$class:$file_name:$line" ;
	}
	
my ($post_depend, $meta_slave, $creator) ;

for my $rule_type (@$rule_types, @$depender_generated_types)
	{
	$creator++     if $rule_type eq CREATOR ;
	$meta_slave++  if $rule_type eq META_SLAVE ;
	$post_depend++ if $rule_type eq POST_DEPEND ;
	}

if($post_depend && $creator)
	{
	Carp::carp ERROR("Rule can't be 'POST_DEPEND' and define a creator.") ;
	PbsDisplayErrorWithContext($file_name,$line) ;
	die ;
	}
	
my $rule_definition = 
	{
	  TYPE                => $rule_types
	, NAME                => $name
	, ORIGIN              => $origin
	, FILE                => $file_name
	, LINE                => $line
	, DEPENDER            => $depender_sub
	, TEXTUAL_DESCRIPTION => $depender_definition # keep a visual on how the rule was defined
	, BUILDER             => $builder_sub
	, %$builder_generated_types
	} ;


if(defined $node_subs)
	{
	if('ARRAY' eq ref $node_subs)
		{
		for my $node_sub (@$node_subs)
			{
			if('CODE' ne ref $node_sub)
				{
				PrintError("Invalid node sub at rule '$name' @ '$file_name:$line'. Expecting a sub or a sub array.\n") ;
				PbsDisplayErrorWithContext($file_name,$line) ;
				die ;
				}
			}
		}
	elsif('CODE' eq ref $node_subs)
		{
		$node_subs = [$node_subs] ;
		}
	else
		{
		PrintError("Invalid node sub at rule '$name' @ '$file_name:$line'. Expecting a sub or a sub array.\n") ;
		PbsDisplayErrorWithContext($file_name,$line) ;
		die ;
		}
	}
else
	{
	$node_subs = [] ;
	}
	
push @$node_subs, @$node_subs1 if $node_subs1 ;
push @$node_subs, @$node_subs2 if $node_subs2 ;

$rule_definition->{NODE_SUBS} = $node_subs if @$node_subs ;

if(defined $pbs_config->{DEBUG_DISPLAY_RULES})
	{
	my $class_info = "[$class" ;
	$class_info .= ' (POST_DEPEND)' if $post_depend ;
	$class_info .= ' (META_SLAVE)' if $meta_slave ;
	$class_info .= ' (CREATOR)' if $creator ;
	$class_info .= ']' ;
		
	if('HASH' eq ref $depender_definition)
		{
		PrintInfo("Registering subpbs rule: $class_info $name$origin")  ;
		}
	else
		{
		PrintInfo("Registering rule: $class_info $name$origin")  ;
		}
		
	PrintInfo(DumpTree($rule_definition)) if defined $pbs_config->{DEBUG_DISPLAY_RULE_DEFINITION} ;
	PrintInfo("\n")  ;
	}

push @{$package_rules{$package}{$class}}, $rule_definition ;
}

#-------------------------------------------------------------------------------

sub RemoveRule
{
# if no name is given, all the rules in the package-class are removed.

my $package = shift ;
my $class   = shift ;
my $name    = shift ;

if(defined $name)
	{
	if(exists $package_rules{$package}{$class})
		{
		my $rules = $package_rules{$package}{$class} ;
		
		my @new_rules;
		
		for my $rule (@$rules)
			{
			if($rule->{NAME} !~ /^$name($|(\s+:))/)
				{
				push @new_rules, $rule ;
				}
			else
				{
				#~print "Removing rule: '$rule->{NAME}'\n" ; 
				}
			}
			
		$package_rules{$package}{$class} = \@new_rules ;
		}
	}
else
	{
	delete $package_rules{$package}{$class} ;
	}
	
$name ||= 'NO_NAME!' ;	

my $pbs_config = PBS::PBSConfig::GetPbsConfig($package) ;
PrintInfo("Removing Rule: ${package}::${class}::${name}\n") if defined $pbs_config->{DEBUG_DISPLAY_RULES} ;
}

#-------------------------------------------------------------------------------

sub DisplayAllRules
{
PrintInfo(DumpTree(\%package_rules, 'All rules:')) ;
}

#-------------------------------------------------------------------------------

sub BuildOk
{
# Syntactic sugar, this function can be called instead for 
# defining a closure or giving a sub ref

my $message = shift || '' ;
my $print   = shift || 0 ;

my ($package, $file_name, $line) = caller() ;

return 
	(
	sub
		{
		my ($config, $file_to_build, $dependencies, $triggering_dependencies, $file_tree, $inserted_nodes) = @_ ;
		
		PrintUser($message . "\n") if $print ;
		return(1, $message) ;
		}
	) ;
}


#-------------------------------------------------------------------------------

sub AddSubpbsRule
{
# Syntactic sugar, this function can be called instead for 
# AddRule .. { subpbs_definition}
# the compulsory arguments come first, then one can pass 
# key-value pairs as in a normal subpbs definition

my ($package, $file_name, $line) = caller() ;
$file_name =~ s/^'// ;
$file_name =~ s/'$// ;

my $rule_definition = \@_ ;

my ($rule_name, $node_regex, $Pbsfile, $pbs_package, @other_setup_data) 
	= RunUniquePluginSub('AddSubpbsRule', $file_name, $line, $rule_definition) ;

RegisterRule
	(
	$file_name, $line, $package
	, 'User'
	, [UNTYPED]
	, $rule_name
	, {
	    NODE_REGEX         => $node_regex
	  , PBSFILE            => $Pbsfile
	  , PACKAGE            => $pbs_package
	  #~ , IGNORE_LOCAL_RULES => 1
	  , @other_setup_data
	  }
	, undef
	, undef
	) ;
}

#-------------------------------------------------------------------------------

1 ;

__END__
=head1 NAME

PBS::Rules::Rules - Manipulate PBS rules

=head1 SYNOPSIS

	# within a Pbsfile
	AddRule 'all_lib', ['all' => qw(lib.lib)], BuildOk() ;
	AddRule 'test', ['test' => 'all', 'test1', 'test2'] ;
	

=head1 DESCRIPTION

This modules defines a set of functions to add, remove and replace B<PBS> rules. B<PBS> rules can be written
in pure perl code or with a syntax ressembling that of I<make>. I<RegisterRule> converts the I<make> like 
definitions to perl code when needed.

=head2 EXPORT

	AddRule AddRuleTo 
	AddSubpbsRule 
	RemoveRule 
	ReplaceRule ReplaceRuleTo 
	BuildOk

=head1 AUTHOR

Khemir Nadim ibn Hamouda. nadim@khemir.net

=head1 SEE ALSO

B<PBS> reference manual.

=cut
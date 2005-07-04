=head1 PBSFILE USER HELP

Test digest and dependency files

=head2 Top rules

=over 2 

=item * 'all'

=back

=cut

PbsUse('Configs/gcc') ;

use Cwd ;
AddConfig CFLAGS_INCLUDE => '-I ' . cwd . ' ' ;

if(GetConfig('debug'))
	{
	AddConfig CFLAGS => GetConfig('CFLAGS') . ' -g ' ;
	}

AddVariableDependencies(CFLAGS => GetConfig('CFLAGS')) ;

#--------------------------------------------------------------------

AddRule [VIRTUAL], "top rule 'all'", ['all' => 'a.out'], BuildOk("Done with top rule 'all'") ;

AddRule  'a.out', ['a.out' => 'main/main.o', 'world/world.o']
	, ["%CC -o %FILE_TO_BUILD %DEPENDENCY_LIST"] ;

AddSubpbsRule 'world subpbs', 'world/world.o', './world/world.pl', 'WORLD' ;
AddSubpbsRule 'main subpbs',  'main/main.o',   './main/main.pl',   'MAIN' ;


#--------------------------------------------------------------------

AddRule [VIRTUAL, FORCED], 'test', ['test' => 'a.out'],
		[ "%DEPENDENCY_LIST"] ;


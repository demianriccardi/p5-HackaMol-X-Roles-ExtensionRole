package HackaMol::X::Roles::ExtensionRole;

# ABSTRACT: Role to assist writing HackaMol extensions to external programs
use 5.008;
use Moose::Role;
use Capture::Tiny ':all';
use File::chdir;
use Carp;

with qw(HackaMol::Roles::ExeRole HackaMol::Roles::PathRole);

requires qw(_build_map_in _build_map_out build_command);

has 'mol' => (
    is  => 'rw',
    isa => 'HackaMol::Molecule',
    predicate => 'has_mol'
);

has 'map_in' => (
    is        => 'ro',
    isa       => 'CodeRef',
    predicate => 'has_map_in',
    builder   => '_build_map_in',
    lazy      => 1,
);
has 'map_out' => (
    is        => 'ro',
    isa       => 'CodeRef',
    predicate => 'has_map_out',
    builder   => '_build_map_out',
    lazy      => 1,
);

sub map_input {

    # pass everything and anything to map_in... i.e. keep @_ in tact
    my ($self) = @_;
    local $CWD = $self->scratch if ( $self->has_scratch );
    return ( &{ $self->map_in }(@_) );

}

sub map_output {

    # pass everything and anything to map_out... i.e. keep @_ in tact
    my ($self) = @_;
    local $CWD = $self->scratch if ( $self->has_scratch );
    return ( &{ $self->map_out }(@_) );

}

sub capture_sys_command {

    # run it and return all that is captured
    my $self    = shift;
    my $command = shift;
    unless ( defined($command) ) {
        return 0 unless $self->has_command;
        $command = $self->command;
    }

    local $CWD = $self->scratch if ( $self->has_scratch );
    my ( $stdout, $stderr, @exit ) = capture {
        system($command);
    };
    return ( $stdout, $stderr, @exit );
}

no Moose::Role;

1;

__END__

=head1 SYNOPSIS
    
    package HackaMol::X::SomeExtension;
    use Moose;

    with qw(HackaMol::X::Roles::ExtensionRole);

    sub _build_map_in{
      my $sub_cr = sub { return (@_) };
      return $sub_cr;
    }

    sub _build_map_out{
      my $sub_cr = sub { return (@_) };
      return $sub_cr;
    }

    sub BUILD {
      my $self = shift;

      if ( $self->has_scratch ) {
          $self->scratch->mkpath unless ( $self->scratch->exists );
      }
    }

    no Moose;
    1;

=head1 DESCRIPTION

The HackaMol::X::Roles::ExtensionRole includes methods and attributes that are useful for building extensions
with code reuse.  This role will improve as extensions are written and needs arise.  This role is flexible
and can be encapsulated and rigidified in extensions.  Advanced use of extensions should still be able to 
access this flexibility to allow tinkering with internals!  Consumes HackaMol::Roles::ExeRole and HackaMol::Roles::PathRole
... ExeRole may be removed from core and wrapped in here.

=attr scratch

Coerced to be 'Path::Tiny' via AbsPath. If scratch is set, map_input and map_output will local CWD to the
scratch to carry out operations. See HackaMol::PathRole for more information about the scratch attribute 
and other attributes available (such as in_fn and out_fn).

=attr mol

isa HackaMol::Molecule that is ro

=attr map_in

isa CodeRef that is ro.  The default builder is required for consuming classes.

intended for mapping input files from molecular information, but it is completely
flexible. Used in map_input method.  Can also be directly ivoked,

  &{$calc->map_in}(@args); 

as any other subroutine would be. Extensions can build the map_in function so that it returns 
the content of $input which can then be written within API methods.

=attr map_out

isa CodeRef that is ro.  The default builder is required for consuming classes.

intended for mapping molecular information from output files, but it is completely
flexible and analogous to map_in. 

=method map_input

the main function is to change to scratch directory, if set, and pass all arguments (including self) to 
map_in CodeRef.

  $calc->map_input(@args);

will invoke,

  &{$calc->map_in}(@_);  #where @_ = ($self,@args)

and return anything returned by the map_in function. Thus, any input writing should take place in map_in 
inorder to actually write to the scratch directory.

=method map_output

completely analogous to map_input.  Thus, the output must be opened and processed in the
map_out function.

=method build_command 

builds the command from the attributes: exe, inputfn, exe_endops, if they exist, and returns
the command.

=method capture_sys_command

uses Capture::Tiny capture method to run a command using a system call. STDOUT, STDERR, are
captured and returned.

  my ($stdout, $stderr,@other) = capture { system($command) }

the $command is taken from $calc->command unless the $command is passed,

  $calc->capture_sys_command($some_command);

capture_sys_command returns ($stdout, $stderr,@other) or 0 if there is no command set.

CODE STRUCTURE
==============

### DesignCreate::Cmd
* Setup file for MooseX::App::Command commands
* Specifies to look in _lib/DesignCreate/Action/_ folder

### DesignCreate::Action
* Consumes **DesignCreate::Role::Action** role
* Consumes **DesignCreate::Role::EnsEMBL** role
* Parent class to all the DesignCreate::Action::\* modules
* Extends MooseX::App::Cmd::Command
* sets up some common attributes
* sets up logging ( via Log4Perl )
* modifies command line command names

### DesignCreate::Action::\*
* Each file here represents a command that can be invoked through the command line
* Mostly just setup code, the bulk of the functional code is stored in the matching module in the CmdRole directory
* See [COMMAND ROLES](#command-roles) section for reasoning behind this choice.

### Overall Commands
* These do not have a counterpart module in the CmdRole directory but consume multiple DesignCreate::CmdRole roles

```
 DesignCreate::Action::ConditionalDesign
 DesignCreate::Action::GibsonDesign
 DesignCreate::Action::InsDelDesign
 DesignCreate::Action::DelExonDesign
```

### Individual Commands
* These are the individial command modules along with their corresponding CmdRole
* These CmdRole modules can also consume multiple other roles
* The arrows below represent the roles that are consumed by modules to the left

```
 DesignCreate::Action::ConsolidateDesignData     -> DesignCreate::CmdRole::ConsolidateDesignData
 DesignCreate::Action::FetchOligoRegionsSequence -> DesignCreate::CmdRole::FetchOligoRegionsSequence
 DesignCreate::Action::FilterGibsonOligos        -> DesignCreate::CmdRole::FilterGibsonOligos
 DesignCreate::Action::FilterOligos              -> DesignCreate::CmdRole::FilterOligos
                                                             -> DesignCreate::Role::FilterOligos
 DesignCreate::Action::FindGibsonOligos          -> DesignCreate::CmdRole::FindGibsonOligos
                                                             -> DesignCreate::Role::FilterOligos
 DesignCreate::Action::FindOligos                -> DesignCreate::CmdRole::FindOligos
                                                             -> DesignCreate::Role::AOS
 DesignCreate::Action::OligoPairRegionsGibson    -> DesignCreate::CmdRole::OligoPairRegionsGibson
                                                             -> DesignCreate::Role::OligoRegionCoordinates
 DesignCreate::Action::OligoRegionsConditional   -> DesignCreate::CmdRole::OligoRegionsConditional
                                                             -> DesignCreate::Role::OligoRegionCoordinates
                                                             -> DesignCreate::Role::GapOligoCoordinates
 DesignCreate::Action::OligoRegionsDelExon       -> DesignCreate::CmdRole::OligoRegionsDelExon
                                                             -> DesignCreate::Role::OligoRegionCoordinates
                                                             -> DesignCreate::Role::GapOligoCoordinates
                                                             -> DesignCreate::Role::OligoRegionCoordinatesInsDel
 DesignCreate::Action::OligoRegionsInsDel        -> DesignCreate::CmdRole::OligoRegionsInsDel
                                                             -> DesignCreate::Role::OligoRegionCoordinates
                                                             -> DesignCreate::Role::GapOligoCoordinates
                                                             -> DesignCreate::Role::OligoRegionCoordinatesInsDel
 DesignCreate::Action::PersistDesign             -> DesignCreate::CmdRole::PersistDesign
 DesignCreate::Action::PickBlockOligos           -> DesignCreate::CmdRole::PickBlockOligos
 DesignCreate::Action::PickGapOligos             -> DesignCreate::CmdRole::PickGapOligos
 DesignCreate::Action::RunAOS                    -> DesignCreate::CmdRole::RunAOS
                                                             -> DesignCreate::Role::AOS
```


### Exception Handling
* These modules handle throwing expections, subclasses are for specific types of errors

```
    DesignCreate::Exception
    DesignCreate::Exception::MissingFile
    DesignCreate::Exception::NonExistantAttribute
```

### Helper Modules
* Code used by various modules in the code base.

```
    DesignCreate::Types
    DesignCreate::Util::Exonerate
    DesignCreate::Util::PickBlockOligoPair
    DesignCreate::Util::Primer3
    DesignCreate::Constants
```

TESTS
=====

* Use Test::Class as framework for tests
* Uses Class::Data::Inheritable to set up class variables
* We can't test against the command modules themselves because they use MooseX::App::Cmd and these modules can only be created from the command line
* To unit test this code we need to create a object and make it consume the DesignCreate::CmdRole role we want to test against
* We Use dynamically created Moose::Meta::Class's to test against
    * This is done so we don't need to create multiple boilerplate test classes that only differ by what role they consume

### Test::DesignCreate::Class
* Base Test::Class object, all test modules are children of this class.
* Has a get_test_object_metaclass method that creates metaclasses for test objects we test against.
    * The base class for the test objects is Test::ObjectRole::DesignCreate ( see below )
    * The test object consumes the role that is currently being tested ( defined by class data: test_role )
    * A metaclass is created, from this the new functions can be called to create test object
    * Also can optionally consume extra roles if required

### Test::ObjectRole::DesignCreate
* Superclass for all test objects
* Like a cut down version of DesignCreate::Action
* Does not consume MooseX::App::Cmd, skips attributes directly linked to it as well


COMMAND ROLES
=============

Pro's
-----
* Testing easier, consume role, can unit test
* Can provide commands that invoke multiple cmd-roles

Con's
-----
* Attribute name clashes
* Method name clashes
* Role can not require a method / attribute that is provided by another role

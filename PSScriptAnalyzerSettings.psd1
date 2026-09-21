@{
    Severity     = @('Error', 'Warning')

    # These tools are interactive operator scripts: coloured console output is the point,
    # not a defect. Everything they return as data is written to the pipeline separately.
    ExcludeRules = @('PSAvoidUsingWriteHost')
}

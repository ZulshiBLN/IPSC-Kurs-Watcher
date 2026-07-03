@{
    IncludeRules = @(
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidUsingBrokenHashProperties',
        'PSAvoidUsingDoubleQuotedStrings',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingUserNameAndPassWordParams',
        'PSAvoidUsingWildcardCharactersInCommandName',
        'PSProvideCommentHelp',
        'PSUseApprovedVerbs',
        'PSUseBOMForUnicodeEncodedFile',
        'PSUseCmdletCorrectly',
        'PSUseCompatibleCmdlets',
        'PSUseConsistentIndentation',
        'PSUseConsistentWhitespace',
        'PSUseOutputTypeCorrectly'
    )

    Rules = @{
        PSAvoidUsingDoubleQuotedStrings = @{
            Enable = $false
        }
        PSAvoidUsingInvokeExpression = @{
            Enable = $true
        }
        PSProvideCommentHelp = @{
            Enable = $true
            ExportedOnly = $true
            BlockComment = $true
            VSCodeSnippetCorrection = $false
            Placement = 'before'
        }
        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            IndentationSize = 4
        }
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckSeparator = $true
            CheckPipe = $true
            CheckParameter = $false
        }
    }

    Severity = @{
        'PSAvoidUsingInvokeExpression' = 'Error'
        'PSProvideCommentHelp' = 'Error'
        'PSUseConsistentIndentation' = 'Warning'
        'PSUseConsistentWhitespace' = 'Warning'
    }

    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
    )
}

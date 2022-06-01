%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, parens: true}
      ]
    }
  ]
}

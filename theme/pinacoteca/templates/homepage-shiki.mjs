/**
 * Pinacoteca — Shiki/TextMate theme.
 * Mirrors the site-wide palette so code blocks match the editor theme.
 * Source of truth: dotfiles/theme/pinacoteca/colors.toml
 */
export const pinacoteca = {
  name: "pinacoteca",
  type: "dark",
  colors: {
    "editor.background": "{{bg0:l=16.5:upper}}",
    "editor.foreground": "{{fg:upper}}",
    "editorLineNumber.foreground": "{{bg3:upper}}",
    "editor.selectionBackground": "{{bg3:upper}}",
  },
  settings: [
    {
      settings: {
        background: "{{bg0:l=16.5:upper}}",
        foreground: "{{fg:upper}}",
      },
    },
    {
      scope: ["comment", "punctuation.definition.comment", "string.comment"],
      settings: { foreground: "{{comment:upper}}", fontStyle: "italic" },
    },
    {
      scope: [
        "punctuation",
        "meta.brace",
        "punctuation.separator",
        "punctuation.terminator",
        "punctuation.definition.string",
        "keyword.operator",
        "punctuation.separator.key-value",
        "storage.type.function.arrow",
        "punctuation.definition.tag",
      ],
      settings: { foreground: "{{fg_dim:upper}}" },
    },
    {
      scope: [
        "variable",
        "variable.other",
        "variable.parameter",
        "variable.other.property",
        "variable.other.object.property",
        "meta.object-literal.key",
        "support.variable",
        "entity.other.attribute-name",
        "entity.name.namespace",
      ],
      settings: { foreground: "{{fg:upper}}" },
    },
    {
      scope: ["variable.language", "support.variable.property.dom"],
      settings: { foreground: "{{red:upper}}" },
    },
    {
      scope: ["string", "string.quoted", "string.template", "markup.inline.raw"],
      settings: { foreground: "{{green:upper}}" },
    },
    {
      scope: [
        "constant.character.escape",
        "string.regexp",
        "punctuation.definition.template-expression",
        "punctuation.section.embedded",
      ],
      settings: { foreground: "{{aqua:upper}}" },
    },
    {
      scope: [
        "entity.name.function",
        "support.function",
        "meta.function-call.generic",
        "variable.function",
        "entity.name.tag",
      ],
      settings: { foreground: "{{blue:upper}}" },
    },
    {
      scope: [
        "entity.name.type",
        "entity.name.class",
        "support.type",
        "support.class",
        "entity.other.inherited-class",
        "meta.type.name",
        "entity.name.type.module",
      ],
      settings: { foreground: "{{gold:upper}}" },
    },
    {
      scope: [
        "keyword",
        "keyword.control",
        "storage",
        "storage.type",
        "storage.modifier",
        "keyword.other.special-method",
        "keyword.other.unit",
      ],
      settings: { foreground: "{{purple:upper}}" },
    },
    {
      scope: [
        "constant.numeric",
        "constant.language",
        "constant.character",
        "constant.other",
        "support.constant",
      ],
      settings: { foreground: "{{orange:upper}}" },
    },
    {
      scope: ["markup.heading", "entity.name.section"],
      settings: { foreground: "{{gold:upper}}", fontStyle: "bold" },
    },
    { scope: ["markup.bold"], settings: { fontStyle: "bold" } },
    { scope: ["markup.italic"], settings: { fontStyle: "italic" } },
    {
      scope: ["markup.underline.link", "string.other.link"],
      settings: { foreground: "{{blue:upper}}" },
    },
    { scope: ["markup.inserted"], settings: { foreground: "{{green:upper}}" } },
    { scope: ["markup.deleted"], settings: { foreground: "{{red:upper}}" } },
    { scope: ["markup.changed"], settings: { foreground: "{{blue:upper}}" } },
    { scope: ["invalid", "invalid.illegal"], settings: { foreground: "{{red:upper}}" } },
    {
      scope: ["support.type.property-name", "meta.property-name", "entity.name.tag.toml"],
      settings: { foreground: "{{blue:upper}}" },
    },
  ],
};

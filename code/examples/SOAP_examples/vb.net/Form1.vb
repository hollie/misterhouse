Public Class Form1
    Inherits System.Windows.Forms.Form

    Private ws As MySoapRef.mhsoap

#Region " Windows Form Designer generated code "

    Public Sub New()
        MyBase.New()

        'This call is required by the Windows Form Designer.
        InitializeComponent()

        'Add any initialization after the InitializeComponent() call
        
    End Sub

    'Form overrides dispose to clean up the component list.
    Protected Overloads Overrides Sub Dispose(ByVal disposing As Boolean)
        If disposing Then
            If Not (components Is Nothing) Then
                components.Dispose()
            End If
        End If
        MyBase.Dispose(disposing)
    End Sub

    'Required by the Windows Form Designer
    Private components As System.ComponentModel.IContainer

    'NOTE: The following procedure is required by the Windows Form Designer
    'It can be modified using the Windows Form Designer.  
    'Do not modify it using the code editor.
    Friend WithEvents ComboBox1 As System.Windows.Forms.ComboBox
    Friend WithEvents ListBox1 As System.Windows.Forms.ListBox
    Friend WithEvents Label1 As System.Windows.Forms.Label
    Friend WithEvents cmdConnect As System.Windows.Forms.Button
    Friend WithEvents Label2 As System.Windows.Forms.Label
    Friend WithEvents txtNewState As System.Windows.Forms.TextBox
    Friend WithEvents cmdSetState As System.Windows.Forms.Button
    Friend WithEvents txtURL As System.Windows.Forms.TextBox
    Friend WithEvents lblState As System.Windows.Forms.Label
    <System.Diagnostics.DebuggerStepThrough()> Private Sub InitializeComponent()
        Me.ComboBox1 = New System.Windows.Forms.ComboBox
        Me.ListBox1 = New System.Windows.Forms.ListBox
        Me.txtURL = New System.Windows.Forms.TextBox
        Me.Label1 = New System.Windows.Forms.Label
        Me.cmdConnect = New System.Windows.Forms.Button
        Me.Label2 = New System.Windows.Forms.Label
        Me.lblState = New System.Windows.Forms.Label
        Me.txtNewState = New System.Windows.Forms.TextBox
        Me.cmdSetState = New System.Windows.Forms.Button
        Me.SuspendLayout()
        '
        'ComboBox1
        '
        Me.ComboBox1.Location = New System.Drawing.Point(8, 72)
        Me.ComboBox1.Name = "ComboBox1"
        Me.ComboBox1.Size = New System.Drawing.Size(272, 21)
        Me.ComboBox1.TabIndex = 0
        Me.ComboBox1.Text = "Press Connect to fill me"
        '
        'ListBox1
        '
        Me.ListBox1.Location = New System.Drawing.Point(8, 104)
        Me.ListBox1.Name = "ListBox1"
        Me.ListBox1.Size = New System.Drawing.Size(272, 199)
        Me.ListBox1.TabIndex = 1
        '
        'txtURL
        '
        Me.txtURL.Location = New System.Drawing.Point(136, 24)
        Me.txtURL.Name = "txtURL"
        Me.txtURL.Size = New System.Drawing.Size(136, 20)
        Me.txtURL.TabIndex = 2
        Me.txtURL.Text = "http://misterhouse:8080"
        '
        'Label1
        '
        Me.Label1.Location = New System.Drawing.Point(16, 24)
        Me.Label1.Name = "Label1"
        Me.Label1.Size = New System.Drawing.Size(112, 16)
        Me.Label1.TabIndex = 3
        Me.Label1.Text = "Misterhouse URL"
        '
        'cmdConnect
        '
        Me.cmdConnect.Location = New System.Drawing.Point(336, 24)
        Me.cmdConnect.Name = "cmdConnect"
        Me.cmdConnect.Size = New System.Drawing.Size(104, 24)
        Me.cmdConnect.TabIndex = 4
        Me.cmdConnect.Text = "Connect"
        '
        'Label2
        '
        Me.Label2.Location = New System.Drawing.Point(296, 112)
        Me.Label2.Name = "Label2"
        Me.Label2.Size = New System.Drawing.Size(40, 16)
        Me.Label2.TabIndex = 5
        Me.Label2.Text = "State :"
        '
        'lblState
        '
        Me.lblState.BorderStyle = System.Windows.Forms.BorderStyle.Fixed3D
        Me.lblState.Location = New System.Drawing.Point(360, 112)
        Me.lblState.Name = "lblState"
        Me.lblState.Size = New System.Drawing.Size(80, 16)
        Me.lblState.TabIndex = 6
        Me.lblState.Text = "Unknown"
        '
        'txtNewState
        '
        Me.txtNewState.Location = New System.Drawing.Point(360, 136)
        Me.txtNewState.Name = "txtNewState"
        Me.txtNewState.Size = New System.Drawing.Size(80, 20)
        Me.txtNewState.TabIndex = 7
        Me.txtNewState.Text = ""
        '
        'cmdSetState
        '
        Me.cmdSetState.Location = New System.Drawing.Point(296, 136)
        Me.cmdSetState.Name = "cmdSetState"
        Me.cmdSetState.Size = New System.Drawing.Size(48, 24)
        Me.cmdSetState.TabIndex = 8
        Me.cmdSetState.Text = "Set"
        '
        'Form1
        '
        Me.AutoScaleBaseSize = New System.Drawing.Size(5, 13)
        Me.ClientSize = New System.Drawing.Size(472, 318)
        Me.Controls.Add(Me.cmdSetState)
        Me.Controls.Add(Me.txtNewState)
        Me.Controls.Add(Me.lblState)
        Me.Controls.Add(Me.Label2)
        Me.Controls.Add(Me.cmdConnect)
        Me.Controls.Add(Me.Label1)
        Me.Controls.Add(Me.txtURL)
        Me.Controls.Add(Me.ListBox1)
        Me.Controls.Add(Me.ComboBox1)
        Me.Name = "Form1"
        Me.Text = "Misterhouse Test Client"
        Me.ResumeLayout(False)

    End Sub

#End Region


    Private Sub Form1_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles MyBase.Load
        System.Net.ServicePointManager.Expect100Continue = False

        ws = New MySoapRef.mhsoap
        
    End Sub

    

    Private Sub ComboBox1_SelectedValueChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles ComboBox1.SelectedValueChanged
        Dim results As String()
        Dim i As Integer

        results = ws.ListObjectsByType(ComboBox1.Text)

        With ListBox1
            .BeginUpdate()
            For i = .Items.Count - 1 To 0 Step -1
                .Items.Remove(.Items(0))
            Next i

            For i = 0 To UBound(results)
                .Items.Add(results(i))
            Next i
            .EndUpdate()
        End With
    End Sub

    Private Sub cmdConnect_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles cmdConnect.Click
        Dim i As Integer
        Dim results As String()

        ws.Url = txtURL.Text & "/bin/soapcgi.pl"

        results = ws.ListObjectTypes()

        With ComboBox1
            .Text = "Choose Type"
            For i = 0 To UBound(results)
                .Items.Add(results(i))
            Next
        End With
    End Sub

    Private Sub ListBox1_SelectedIndexChanged(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles ListBox1.SelectedIndexChanged

    End Sub

    Private Sub ListBox1_SelectedValueChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles ListBox1.SelectedValueChanged
        Dim stState As String

        Dim stItem As String

        stItem = ListBox1.SelectedItem

        If Mid(stItem, 1, 1) = "$" Then
            stItem = stItem.Remove(0, 1)
        End If

        stState = ws.GetItemState(stItem)

        lblState.Text = stState

    End Sub

    Private Sub cmdSetState_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles cmdSetState.Click

        Dim iReturn As Integer
        Dim stItem As String
        Dim stState As String

        stItem = ListBox1.SelectedItem

        If Mid(stItem, 1, 1) = "$" Then
            stItem = stItem.Remove(0, 1)
        End If

        stState = txtNewState.Text
        iReturn = ws.SetItemState(stItem, stState)

        lblState.Text = txtNewState.Text

    End Sub
End Class

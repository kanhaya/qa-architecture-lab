package com.qa.loanservice.service;

import com.qa.loanservice.exception.LoanNotFoundException;
import com.qa.loanservice.model.Loan;
import com.qa.loanservice.model.LoanStatus;
import com.qa.loanservice.model.requests.CreateLoanRequest;
import com.qa.loanservice.model.requests.UpdateLoanStatusRequest;
import com.qa.loanservice.repository.LoanRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class LoanServiceTest {

    @Mock
    private LoanRepository loanRepository;

    @InjectMocks
    private LoanService loanService;

    private Loan existingLoan;

    @BeforeEach
    void setUp() {
        existingLoan = new Loan(101L, "Rahul", 500_000L, LoanStatus.APPROVED);
    }

    @Test
    void getAllLoans_returnsAllLoans() {
        when(loanRepository.findAll()).thenReturn(List.of(existingLoan));

        List<Loan> loans = loanService.getAllLoans();

        assertThat(loans).hasSize(1);
        assertThat(loans.getFirst().getId()).isEqualTo(101L);
    }

    @Test
    void getLoanById_whenExists_returnsLoan() {
        when(loanRepository.findById(101L)).thenReturn(Optional.of(existingLoan));

        Loan loan = loanService.getLoanById(101L);

        assertThat(loan.getCustomerName()).isEqualTo("Rahul");
    }

    @Test
    void getLoanById_whenNotFound_throwsException() {
        when(loanRepository.findById(999L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> loanService.getLoanById(999L))
                .isInstanceOf(LoanNotFoundException.class)
                .hasMessageContaining("999");
    }

    @Test
    void createLoan_setsPendingStatusAndSaves() {
        CreateLoanRequest request = new CreateLoanRequest();
        request.setCustomerName("Amit");
        request.setAmount(300_000L);

        when(loanRepository.save(any(Loan.class))).thenAnswer(invocation -> {
            Loan loan = invocation.getArgument(0);
            loan.setId(103L);
            return loan;
        });

        Loan created = loanService.createLoan(request);

        ArgumentCaptor<Loan> captor = ArgumentCaptor.forClass(Loan.class);
        verify(loanRepository).save(captor.capture());

        assertThat(created.getId()).isEqualTo(103L);
        assertThat(created.getStatus()).isEqualTo(LoanStatus.PENDING);
        assertThat(captor.getValue().getCustomerName()).isEqualTo("Amit");
        assertThat(captor.getValue().getAmount()).isEqualTo(300_000L);
    }

    @Test
    void updateStatus_whenExists_updatesAndReturnsLoan() {
        UpdateLoanStatusRequest request = new UpdateLoanStatusRequest();
        request.setStatus(LoanStatus.REJECTED);

        when(loanRepository.findById(101L)).thenReturn(Optional.of(existingLoan));
        when(loanRepository.save(any(Loan.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Loan updated = loanService.updateStatus(101L, request);

        assertThat(updated.getStatus()).isEqualTo(LoanStatus.REJECTED);
    }

    @Test
    void updateStatus_whenNotFound_throwsException() {
        UpdateLoanStatusRequest request = new UpdateLoanStatusRequest();
        request.setStatus(LoanStatus.APPROVED);

        when(loanRepository.findById(999L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> loanService.updateStatus(999L, request))
                .isInstanceOf(LoanNotFoundException.class);
    }

    @Test
    void deleteLoan_whenExists_deletesSuccessfully() {
        when(loanRepository.deleteById(101L)).thenReturn(true);

        loanService.deleteLoan(101L);

        verify(loanRepository).deleteById(101L);
    }

    @Test
    void deleteLoan_whenNotFound_throwsException() {
        when(loanRepository.deleteById(999L)).thenReturn(false);

        assertThatThrownBy(() -> loanService.deleteLoan(999L))
                .isInstanceOf(LoanNotFoundException.class);

        verify(loanRepository).deleteById(999L);
    }
}
